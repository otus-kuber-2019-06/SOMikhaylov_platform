FROM python
COPY ./app /app
EXPOSE 8000
USER 1001:1001
CMD python3 -m http.server 8000 --directory /app
