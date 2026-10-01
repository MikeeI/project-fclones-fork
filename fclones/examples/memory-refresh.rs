//! Isolates Linux memory-query costs without changing the process page cache.

use std::error::Error;
use std::hint::black_box;
use std::time::Instant;

use clap::Parser;
use serde::Serialize;
use sysinfo::{System, SystemExt};

const DEFAULT_ITERATIONS: u32 = 10_000;
const DEFAULT_RUNS: u32 = 3;

#[derive(Parser)]
struct Options {
    #[arg(long, default_value_t = DEFAULT_ITERATIONS, value_parser = clap::value_parser!(u32).range(1..))]
    iterations: u32,
    #[arg(long, default_value_t = DEFAULT_RUNS, value_parser = clap::value_parser!(u32).range(1..))]
    runs: u32,
    #[arg(long)]
    json: bool,
}

#[derive(Serialize)]
struct Measurements {
    iterations: u32,
    constructor_seconds: Vec<f64>,
    fresh_refresh_seconds: Vec<f64>,
    reused_refresh_seconds: Vec<f64>,
}

fn measure(iterations: u32, mut operation: impl FnMut()) -> f64 {
    let started = Instant::now();
    for _ in 0..iterations {
        operation();
    }
    started.elapsed().as_secs_f64()
}

fn main() -> Result<(), Box<dyn Error>> {
    let options = Options::parse();
    let mut result = Measurements {
        iterations: options.iterations,
        constructor_seconds: Vec::new(),
        fresh_refresh_seconds: Vec::new(),
        reused_refresh_seconds: Vec::new(),
    };
    for run in 0..options.runs {
        result
            .constructor_seconds
            .push(measure(options.iterations, || {
                black_box(System::new());
            }));
        let fresh = || {
            measure(options.iterations, || {
                let mut system = System::new();
                system.refresh_memory();
                black_box((system.free_memory(), system.total_memory()));
            })
        };
        let mut system = System::new();
        let mut reused = || {
            measure(options.iterations, || {
                system.refresh_memory();
                black_box((system.free_memory(), system.total_memory()));
            })
        };
        // Alternate order so reuse is not always measured after the fresh-object path.
        let (fresh_seconds, reused_seconds) = if run % 2 == 0 {
            (fresh(), reused())
        } else {
            let reused_seconds = reused();
            (fresh(), reused_seconds)
        };
        result.fresh_refresh_seconds.push(fresh_seconds);
        result.reused_refresh_seconds.push(reused_seconds);
    }
    if options.json {
        println!("{}", serde_json::to_string(&result)?);
    } else {
        println!("iterations: {}", result.iterations);
        for (index, ((constructor, fresh), reused)) in result
            .constructor_seconds
            .iter()
            .zip(&result.fresh_refresh_seconds)
            .zip(&result.reused_refresh_seconds)
            .enumerate()
        {
            println!("run: {} constructor_seconds: {:.6} fresh_refresh_seconds: {:.6} reused_refresh_seconds: {:.6}", index + 1, constructor, fresh, reused);
        }
    }
    Ok(())
}
