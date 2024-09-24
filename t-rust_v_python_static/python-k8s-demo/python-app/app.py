from flask import Flask, request
import time

app = Flask(__name__)

def is_prime(n):
    if n < 2:
        return False
    for i in range(2, int(n ** 0.5) + 1):
        if n % i == 0:
            return False
    return True

def count_primes(limit):
    count = 0
    for num in range(2, limit + 1):
        if is_prime(num):
            count += 1
    return count

@app.route('/')
def hello():
    return "Hello from Kubernetes!"

@app.route('/prime')
def prime():
    limit = request.args.get('limit', default=100000, type=int)
    start_time = time.time()
    result = count_primes(limit)
    end_time = time.time()
    execution_time = end_time - start_time
    return f"Number of primes up to {limit}: {result}. Calculated in {execution_time:.2f} seconds."

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=8080)
