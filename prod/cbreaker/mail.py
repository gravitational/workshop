from flask import Flask,jsonify
app = Flask(__name__)

@app.route("/")
def hello():
    return jsonify([
        {"from": "<bob@example.com>", "subject": "lunch at noon tomorrow"},
        {"from": "<alice@example.com>", "subject": "compiler docs"}])

if __name__ == "__main__":
    app.run(host='0.0.0.0')
