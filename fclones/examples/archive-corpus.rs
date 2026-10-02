//! Fork-only benchmark model: preserve sizes and hash-stage partitions without copying source bytes.

use clap::Parser;
use fallible_iterator::FallibleIterator;
use fclones::report::open_report;
use fclones::{FileGroup, FileId, Path};
use rand::rngs::StdRng;
use rand::{RngCore, SeedableRng};
use std::collections::{BTreeMap, HashMap, HashSet};
use std::fs::{self, File, OpenOptions};
use std::io::{self, Seek, SeekFrom, Write};
use std::path::PathBuf;

const PREFIX_BYTES: usize = 4096;
const SUFFIX_THRESHOLD: u64 = 65_536;
const BUFFER_BYTES: usize = 65_536;
const DEFAULT_SEED: u64 = 42;

#[derive(Parser)]
struct Options {
    #[arg(long)]
    inventory: PathBuf,
    #[arg(long)]
    prefix: Option<PathBuf>,
    #[arg(long)]
    suffix: Option<PathBuf>,
    #[arg(long)]
    source: PathBuf,
    #[arg(long)]
    target: PathBuf,
    #[arg(long, default_value_t = DEFAULT_SEED)]
    seed: u64,
    /// Compare partitions instead of generating files; hash values intentionally differ.
    #[arg(long)]
    verify_report: Option<PathBuf>,
}

fn invalid(message: impl std::fmt::Display) -> io::Error {
    io::Error::new(io::ErrorKind::InvalidData, message.to_string())
}

fn groups(report: &PathBuf) -> io::Result<Vec<FileGroup<Path>>> {
    let mut reader = open_report(File::open(report)?)?;
    reader.read_header()?;
    reader.read_groups()?.collect()
}

fn partition(
    groups: &[FileGroup<Path>],
    root: &std::path::Path,
) -> io::Result<Vec<(u64, Vec<PathBuf>)>> {
    let mut result = Vec::with_capacity(groups.len());
    for group in groups {
        let mut paths = group
            .files
            .iter()
            .map(|p| {
                p.to_path_buf()
                    .strip_prefix(root)
                    .map(|p| p.to_path_buf())
                    .map_err(invalid)
            })
            .collect::<io::Result<Vec<_>>>()?;
        paths.sort();
        result.push((group.file_len.0, paths));
    }
    result.sort();
    Ok(result)
}

fn class_map(groups: &[FileGroup<Path>]) -> io::Result<HashMap<Path, usize>> {
    let mut result = HashMap::new();
    for (id, group) in groups.iter().enumerate() {
        for path in &group.files {
            if result.insert(path.clone(), id).is_some() {
                return Err(invalid("Report contains a repeated path"));
            }
        }
    }
    Ok(result)
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let options = Options::parse();
    let source = fs::canonicalize(&options.source)?;
    let inventory = groups(&options.inventory)?;
    if let Some(report) = &options.verify_report {
        let actual = groups(report)?;
        let target = fs::canonicalize(&options.target)?;
        if partition(&inventory, &source)? != partition(&actual, &target)? {
            return Err(invalid("Generated corpus partitions differ from the source model").into());
        }
        println!(
            "{}",
            serde_json::json!({"status": "ok", "groups": inventory.len(), "report": report})
        );
        return Ok(());
    }

    let prefix = groups(
        options
            .prefix
            .as_ref()
            .ok_or_else(|| invalid("--prefix is required for generation"))?,
    )?;
    let suffix = groups(
        options
            .suffix
            .as_ref()
            .ok_or_else(|| invalid("--suffix is required for generation"))?,
    )?;
    let prefix_map = class_map(&prefix)?;
    let suffix_map = class_map(&suffix)?;
    let inventory_map = class_map(&inventory)?;
    if prefix_map.len() != inventory_map.len()
        || suffix_map.len() != inventory_map.len()
        || inventory_map
            .keys()
            .any(|p| !prefix_map.contains_key(p) || !suffix_map.contains_key(p))
    {
        return Err(invalid("Reports do not describe the same file set").into());
    }

    let target_parent = fs::canonicalize(
        options
            .target
            .parent()
            .ok_or_else(|| invalid("Target has no parent"))?,
    )?;
    let relative_parent = target_parent.strip_prefix("/tmp").map_err(invalid)?;
    let temporary_root = relative_parent
        .components()
        .next()
        .ok_or_else(|| invalid("Missing isolated temporary root"))?;
    if !temporary_root
        .as_os_str()
        .to_string_lossy()
        .starts_with("fclones-ssd-")
    {
        return Err(invalid("Target must be under /tmp/fclones-ssd-*").into());
    }
    let target = target_parent.join(
        options
            .target
            .file_name()
            .ok_or_else(|| invalid("Target has no name"))?,
    );
    // A fresh target prevents overwriting any existing dataset, including partial prior experiments.
    fs::create_dir(&target)?;

    let mut size_counts = HashMap::<u64, usize>::new();
    for group in &inventory {
        *size_counts.entry(group.file_len.0).or_default() += group.files.len();
    }
    let mut rng = StdRng::seed_from_u64(options.seed);
    let mut prefixes = Vec::with_capacity(prefix.len());
    let mut used_prefixes = HashMap::<u64, HashSet<Vec<u8>>>::new();
    for group in &prefix {
        let size = group.file_len.0.min(PREFIX_BYTES as u64) as usize;
        let mut bytes = vec![0; size];
        // Short files have a small finite content space; reject accidental synthetic class collisions.
        loop {
            rng.fill_bytes(&mut bytes);
            if used_prefixes
                .entry(group.file_len.0)
                .or_default()
                .insert(bytes.clone())
            {
                break;
            }
        }
        prefixes.push(bytes);
    }
    let mut suffixes = vec![vec![0; PREFIX_BYTES]; suffix.len()];
    for bytes in &mut suffixes {
        rng.fill_bytes(bytes);
    }
    let mut identities = HashMap::<FileId, PathBuf>::new();
    let mut buffer = vec![0; BUFFER_BYTES];
    let mut logical_bytes = 0u64;
    let mut sparse_bytes = 0u64;
    let mut hardlink_aliases = 0usize;
    let mut size_histogram = BTreeMap::<u32, (usize, u64)>::new();
    let mut replica_histogram = BTreeMap::<usize, usize>::new();
    for group in &inventory {
        let len = group.file_len.0;
        *replica_histogram.entry(group.files.len()).or_default() += 1;
        let first = group
            .files
            .first()
            .ok_or_else(|| invalid("Empty report group"))?;
        let prefix_id = prefix_map[first];
        let suffix_id = suffix_map[first];
        if group
            .files
            .iter()
            .any(|p| prefix_map[p] != prefix_id || suffix_map[p] != suffix_id)
        {
            return Err(
                invalid("Full-content groups do not refine prefix/suffix partitions").into(),
            );
        }
        let mut generated_replica = None::<PathBuf>;
        for path in &group.files {
            let original = path.to_path_buf();
            let metadata = fs::symlink_metadata(&original)?;
            if !metadata.is_file() || metadata.len() != len {
                return Err(invalid(
                    "Source changed since inventory or contains a non-regular file",
                )
                .into());
            }
            let relative = original.strip_prefix(&source).map_err(invalid)?;
            let destination = target.join(relative);
            fs::create_dir_all(
                destination
                    .parent()
                    .ok_or_else(|| invalid("File has no parent"))?,
            )?;
            let identity = FileId::new(path)?;
            logical_bytes += len;
            let bucket = if len == 0 {
                0
            } else {
                64 - len.leading_zeros()
            };
            let histogram = size_histogram.entry(bucket).or_default();
            histogram.0 += 1;
            histogram.1 += len;
            if let Some(previous) = identities.get(&identity) {
                fs::hard_link(previous, &destination)?;
                hardlink_aliases += 1;
            } else if let Some(previous) = &generated_replica {
                fs::copy(previous, &destination)?;
            } else {
                let mut file = OpenOptions::new()
                    .write(true)
                    .create_new(true)
                    .open(&destination)?;
                if size_counts[&len] == 1 {
                    // Unique-size files are never hashed by the default duplicate scan; holes preserve
                    // their metadata cost without inventing 140+ GB of irrelevant storage traffic.
                    file.set_len(len)?;
                    sparse_bytes += len;
                } else {
                    let mut remaining = len;
                    while remaining > 0 {
                        let count = remaining.min(BUFFER_BYTES as u64) as usize;
                        rng.fill_bytes(&mut buffer[..count]);
                        file.write_all(&buffer[..count])?;
                        remaining -= count as u64;
                    }
                    file.seek(SeekFrom::Start(0))?;
                    file.write_all(&prefixes[prefix_id])?;
                    if len >= SUFFIX_THRESHOLD {
                        file.seek(SeekFrom::Start(len - PREFIX_BYTES as u64))?;
                        file.write_all(&suffixes[suffix_id])?;
                    }
                }
                generated_replica = Some(destination.clone());
            }
            identities.insert(identity, destination);
        }
    }
    println!(
        "{}",
        serde_json::json!({
            "status": "ok", "seed": options.seed, "source": source, "target": target,
            "files": inventory_map.len(), "content_groups": inventory.len(),
            "prefix_groups": prefix.len(), "suffix_groups": suffix.len(),
            "logical_bytes": logical_bytes, "unique_size_sparse_bytes": sparse_bytes,
            "hardlink_aliases": hardlink_aliases, "replica_histogram": replica_histogram,
            "size_histogram_log2_upper_exclusive": size_histogram,
            "limitations": ["No source content is copied", "Empty directories and symbolic links are not modeled",
                "Physical extent layout, compressibility and page-cache residency are not preserved",
                "Unique-size sparse files are representative only for the default duplicate scan"]
        })
    );
    Ok(())
}
