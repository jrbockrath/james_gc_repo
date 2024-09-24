use actix_web::{get, web, App, HttpResponse, HttpServer, Responder};
use std::time::Instant;

fn is_prime(n: u64) -> bool {
    if n < 2 {
        return false;
    }
    for i in 2..=(n as f64).sqrt() as u64 {
        if n % i == 0 {
            return false;
        }
    }
    true
}

fn count_primes(limit: u64) -> u64 {
    (2..=limit).filter(|&n| is_prime(n)).count() as u64
}

#[get("/")]
async fn hello() -> impl Responder {
    HttpResponse::Ok().body("Hello from Kubernetes!")
}

#[get("/prime")]
async fn prime(web::Query(info): web::Query<std::collections::HashMap<String, u64>>) -> impl Responder {
    let limit = info.get("limit").cloned().unwrap_or(100000);
    let start = Instant::now();
    let result = count_primes(limit);
    let duration = start.elapsed();
    HttpResponse::Ok().body(format!(
        "Number of primes up to {}: {}. Calculated in {:.2} seconds.",
        limit,
        result,
        duration.as_secs_f64()
    ))
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    let port = std::env::var("PORT").unwrap_or_else(|_| "8080".to_string());
    let addr = format!("0.0.0.0:{}", port);
    
    println!("Starting server at: {}", addr);

    HttpServer::new(|| App::new().service(hello).service(prime))
        .bind(addr)?
        .run()
        .await
}
