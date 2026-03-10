FROM public.ecr.aws/lambda/python:3.12

# Pillow for image resizing
RUN pip install --no-cache-dir pillow==10.4.0

COPY app.py ${LAMBDA_TASK_ROOT}/app.py

CMD ["app.handler"]
