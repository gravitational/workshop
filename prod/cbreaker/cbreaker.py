from flask import Flask
import requests
from datetime import datetime, timedelta
from threading import Lock
import logging, sys


app = Flask(__name__)

circuit_tripped_until = datetime.now()
mutex = Lock()

def trip():
    global circuit_tripped_until
    mutex.acquire()
    try:
        circuit_tripped_until = datetime.now() + timedelta(0,30)
        app.logger.info("circuit tripped until %s" %(circuit_tripped_until))
    finally:
        mutex.release()

def is_tripped():
    global circuit_tripped_until    
    mutex.acquire()
    try:
        return datetime.now() < circuit_tripped_until
    finally:
        mutex.release()
    

@app.route("/")
def hello():
    weather = "weather unavailable"
    try:
        if is_tripped():
            return "circuit breaker: service unavailable (tripped)"

        r = requests.get('http://localhost:5000', timeout=1)
        app.logger.info("requesting weather...")
        start = datetime.now()
        app.logger.info("got weather in %s ..." % (datetime.now() - start))
        if r.status_code == requests.codes.ok:
            return r.text
        else:
            trip()
            return "circuit brekear: service unavailable (tripping 1)"
    except:
        app.logger.info("exception: %s", sys.exc_info()[0])
        trip()
        return "circuit brekear: service unavailable (tripping 2)"

if __name__ == "__main__":
    app.logger.addHandler(logging.StreamHandler(sys.stdout))
    app.logger.setLevel(logging.DEBUG)
    app.run(host='0.0.0.0', port=6000)
