use clap::Parser;
use rand::rngs::StdRng;
use rand::{Rng, RngCore, SeedableRng};
use std::fs::File;
use std::io::Write;
use std::path::PathBuf;

const DEFAULT_FILE_SIZE: u64 = 65_538;

#[derive(clap::Parser)]
struct CmdOptions {
    #[clap(short = 'n', long, default_value = "100")]
    count: usize,

    #[clap(short = 'c', long, default_value = "5", value_parser = clap::value_parser!(u32).range(2..))]
    max_group_size: u32,

    /// Bytes per file; use sizes above 256 KiB to exercise memory-status queries.
    #[clap(long, default_value_t = DEFAULT_FILE_SIZE, value_parser = clap::value_parser!(u64).range(1..))]
    size: u64,

    /// Make generated contents and replica counts repeatable.
    #[clap(long)]
    seed: Option<u64>,

    #[clap(default_value = ".")]
    target: PathBuf,
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let options = CmdOptions::parse();
    let size = usize::try_from(options.size)?;
    let mut buf = Vec::new();
    buf.try_reserve_exact(size)?;
    buf.resize(size, 0);
    let mut rng = match options.seed {
        Some(seed) => StdRng::seed_from_u64(seed),
        None => StdRng::from_entropy(),
    };
    for i in 0..options.count {
        let group_size = rng.gen_range(1..options.max_group_size);
        rng.fill_bytes(&mut buf);
        for j in 0..group_size {
            let file_name = options.target.join(format!("file_{i}_{j}.txt"));
            // Benchmark callers own corpus isolation; retain the generator's overwrite semantics.
            let mut file = File::create(file_name)?;
            file.write_all(&buf)?;
        }
    }
    Ok(())
}
