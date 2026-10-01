//! Shows the device mapping and resolved pool sizes used by a grouping configuration.

use std::error::Error;

use clap::Parser;
use fclones::{DiskDevices, GroupConfig};
use serde::Serialize;

#[derive(Parser)]
struct Options {
    #[command(flatten)]
    group: GroupConfig,
    #[arg(long)]
    json: bool,
}

#[derive(Serialize)]
struct DeviceInfo {
    path: String,
    device: String,
    kind: String,
    file_system: String,
    configured_random_threads: usize,
    configured_sequential_threads: usize,
    resolved_random_threads: usize,
    resolved_sequential_threads: usize,
}

fn main() -> Result<(), Box<dyn Error>> {
    let options = Options::parse();
    let devices = DiskDevices::new(&options.group.thread_pool_sizes());
    let mut rows = Vec::new();
    for path in &options.group.paths {
        let path = fclones::Path::from(std::fs::canonicalize(path.to_path_buf())?);
        let device = devices.get_by_path(&path);
        rows.push(DeviceInfo {
            path: path.to_escaped_string(),
            device: device.name.to_string_lossy().into_owned(),
            kind: format!("{:?}", device.disk_kind),
            file_system: device.file_system.clone(),
            configured_random_threads: device.parallelism.random,
            configured_sequential_threads: device.parallelism.sequential,
            resolved_random_threads: device.rand_thread_pool().current_num_threads(),
            resolved_sequential_threads: device.seq_thread_pool().current_num_threads(),
        });
    }
    if options.json {
        println!("{}", serde_json::to_string(&rows)?);
    } else {
        let mut output = csv::WriterBuilder::new()
            .delimiter(b'\t')
            .from_writer(std::io::stdout());
        for row in rows {
            output.serialize(row)?;
        }
        output.flush()?;
    }
    Ok(())
}
