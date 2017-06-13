from __future__ import print_function
from flask import Flask
import requests
from datetime import datetime
app = Flask(__name__)

@app.route("/")
def hello():
    weather = "weather unavailable"
    try:
        print("requesting weather...")
        start = datetime.now()
        r = requests.get('http://weather')
        print("got weather in %s ..." % (datetime.now() - start))
        if r.status_code == requests.codes.ok:
            weather = r.text
    except:
        print("weather unavailable")

    print("requesting mail...")
    r = requests.get('http://mail')
    mail = r.json()
    print("got mail in %s ..." % (datetime.now() - start))

    out = []
    for letter in mail:
        out.append("<li>From: %s Subject: %s</li>" % (letter['from'], letter['subject']))

    return '''<html>
<body>
  <h3>Weather</h3>
  <p>%s</p>
  <h3>Email</h3>
  <p>
    <ul>
      %s
    </ul>
  </p>
</body>
''' % (weather, '<br/>'.join(out))

if __name__ == "__main__":
    app.run(host='0.0.0.0')
