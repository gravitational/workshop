from flask import Flask
import requests
from datetime import datetime, timedelta
from threading import Lock
app = Flask(__name__)

circuit_tripped_util = datetime.now()
mutex = Lock()

def trip():
    print "tripping circuit breaker"
    mutex.acquire()
    try:
        circuit_tripped_util = datetime.now() + timedelta(0,30)
    finally:
        mutex.release()

def is_tripped():
    mutex.acquire()
    try:
        return datetime.now() > circuit_tripped_util
    finally:
        mutex.release()    

@app.route("/")
def hello():
    weather = "weather unavailable"
    try:
        if is_tripped():
            return "circuit breaker: service unavailable (tripped)"
        r = requests.get('http://localhost:5000', timeout=1)
        print "requesting weather..."
        start = datetime.now()
        print "got weather in %s ..." % (datetime.now() - start)
        if r.status_code == requests.codes.ok:
            return r.text
        else:
            trip()
            return "circuit brekear: service unavailable (tripping)"
    except:
        trip()
        return "circuit brekear: service unavailable (tripping)"

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=6000)
