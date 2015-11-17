A web front-end of FastDFS, running on OpenResty.

# Requirements

* [FastDFS](https://github.com/happyfish100/fastdfs)
* Lua 5.1
* [OpenResty](https://openresty.org/)
* [lua-resty-fastdfs](https://github.com/panzy/lua-resty-fastdfs)
* [ImageMagick](https://github.com/leafo/magick) // required by thumb


# How to run this app

    $ mkdir logs
    $ sudo /usr/local/openresty/nginx/sbin/nginx -p `pwd` -c nginx.conf


To test upload, visit this page

    http://localhost:8080/

or use curl:

    $ curl -v -0 -F "file=@123.txt" localhost:8080/upload


# Web API

## Uploading

    POST http://localhost:8080/upload/[<fileid>]

`fileid` is for appending data to existing file,
`fileid = <group-name>/<file-name>`, e.g., 

    group1/M00/00/02/wKgBtFY8BW2ETBr0AAAAAFqCAvc159.txt

Accepted Headers

* Content-Type
    - multipart/form-data
    - application/octet-stream
* ext: file extension, such as "jpg"

Response

    <fileid>
    <file-info-in-JSON>

Example

    upload file "123.txt"
    $ curl -v -0 -F "file=@123.txt" localhost:8080/upload

    Successful response:

        < HTTP/1.1 200 OK
        < Server: openresty/1.9.3.1
        < Date: Fri, 13 Nov 2015 03:41:36 GMT
        < Content-Type: text/html; charset=utf-8
        < Content-Length: 150
        < Connection: close
        <
        group1/M00/00/03/wKgBtFZFW_CEK3fKAAAAAFqCAvc139.txt
        {"create_timestamp":1447386096,"crc32":1518469879,"file_size":4,"source_ip_addr":"192.168.1.180"}


    append file "456.txt" to a existing file
    $ curl -v -0 -F "file=@456.txt" localhost:8080/upload/group1/M00/00/02/wKgBtFY8BW2ETBr0AAAAAFqCAvc159.txt

    upload file "xaa.jpg" as octet stream, ext header is required
    $ curl -v -0 -H 'ext:jpg' -H 'Content-Type:application/octet-stream' --data-binary "@xaa.jpg" localhost:8080/upload

    append file "xab.jpg" as octet stream to a existing file, ext header is not required
    $ curl -v -0 -H 'Content-Type:application/octet-stream' --data-binary "@xab.jpg" localhost:8080/upload/group1/M00/00/02/wKgBtFY8XL-EO6A5AAAAAK6F1KI533.jpg


It's possible for clients to get file id while the uploading is still in progress, see test/full-duplex/java.


## Downloading

    GET http://localhost:8080/<fileid>

Example

    http://localhost:8080/group1/M00/00/02/wKgBtFY8BW2ETBr0AAAAAFqCAvc159.txt


## Querying


    GET http://localhost:8080/query/<fileid>

Example

    http://localhost:8080/query/group1/M00/00/02/wKgBtFY8BW2ETBr0AAAAAFqCAvc159.txt

Response

    {"create_timestamp":1446788879,"crc32":1518469879,"file_size":52,"source_ip_addr":"192.168.1.180"}


