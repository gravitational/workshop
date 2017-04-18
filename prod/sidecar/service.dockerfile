FROM library/python:2.7

RUN pip install flask requests
ADD service.py /service
CMD ["python", "/service.py"]
