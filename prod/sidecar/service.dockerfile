FROM library/python:2.7

RUN pip install flask requests
ADD service.py /service.py
CMD ["python", "/service.py"]
