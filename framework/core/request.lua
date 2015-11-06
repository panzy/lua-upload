-- Copyright (C) xing_lao
--
-- Upload request handler.

local resty_upload = require 'resty.upload'
local config = require "core.config"
local tracker = require "resty.fastdfs.tracker"
local storage = require "resty.fastdfs.storage"

-- prototype of request handler.
local Request = { _VERSION = '0.01' }

local recieve_timeout = config.connect_timeout

local function getextension(filename)
	return filename:match(".+%.(%w+)$")
end

-- Find a FastDFS storage and connect to it, 
-- return resty.fastdfs.storage.
local function init_storage()
	local tk = tracker:new()
	tk:set_timeout(recieve_timeout)
	tk:connect({host = config.tracker_host, port = config.tracker_port})
	local res, err = tk:query_storage_store()
	if not res then
		ngx.log(ngx.ERR, "query storage error:" .. err)
        return
	end
	
	local st = storage:new()
	st:set_timeout(recieve_timeout)
	local ok, err = st:connect(res)
	if not ok then
		ngx.log(ngx.ERR, "connect storage error:" .. err)
        return
	end
    return st
end

local function build_upload_result_from_path(path)
    _, _, group, file = path:find('^/?(group%d+)/(.+)$')
    if group and file then
        ngx.log(ngx.INFO, 'append to ' .. group .. ':' .. file)
        return { group_name = group, file_name = file }
    else
        return nil
    end
end

-- Send data to FastDFS
--
-- return { http-status, msg }
local function send_data(self, st, data) 
    if not self.upload_result then
        --ngx.log(ngx.INFO, 'init uploading ' .. self.extname)
        self.upload_result, err = st:upload_appender_by_buff(data, self.extname)
        if not self.upload_result then
            return 500, "upload(init) error: " .. err
        end
    else
        --ngx.log(ngx.INFO, 'append to /' .. upload_result.group_name .. '/' .. upload_result.file_name)
        local append_result, err = st:append_by_buff(
            self.upload_result.group_name, self.upload_result.file_name, data)
        if not append_result then
            return 500, "upload(append) error: " .. err
        end
    end

    return 200, nil
end

local function handle_octet_stream(self)
    if self.upload_result then
        self.extname = getextension(self.upload_result.file_name)
    else
        self.extname = ngx.req.get_headers()['ext']
        if not self.extname then
            return 400, 'require "ext" header for non-appending '..ct
        end
    end

    local sock, err = ngx.req.socket()
    sock:settimeout(3000)

    local st = init_storage()
    while true do
        data, err, partial = sock:receive(config.chunk_size)
        if data or partial then
            local status, err = send_data(self, st, data or partial)
            if not status == 200 then
                return status, err
            end
        else
            break
        end

        if err == 'closed' then break end
    end

    if self.upload_result then
        return 302, '/'..self.upload_result.group_name..'/'..self.upload_result.file_name
    else
        return 500, 'failed to upload'
    end
end

-- Do the uploading work with multipart/form-data,
-- return { http-status, content }.
local function handle_multipart_formdata(self)
	local form, err = resty_upload:new(config.chunk_size)
	if not form then
        return 500, err
	end
	form:set_timeout(recieve_timeout)
	
	local fieldname
    local st = init_storage()

    if not st then
        return 500, 'cannot to connect to file storage service'
    end

	while true do
		local typ, res, err = form:read()
		if not typ then
			return 500, 'failed to read: ' .. err
		end
		
        -- ngx.log(ngx.INFO, 'resty.upload:read() => ' .. typ)

		if typ == "header" then
            -- read() returns: 'header', {key, value, line}
            -- ngx.log(ngx.INFO, 'header ' .. res[1] .. ' => ' .. res[3])

            -- request payload sample
            --
            -- ------WebKitFormBoundaryXBSGBsBFhERUhA08
            -- Content-Disposition: form-data; name="append"
            --
            -- ------WebKitFormBoundaryXBSGBsBFhERUhA08
            -- Content-Disposition: form-data; name="file"; filename="456.txt"
            -- Content-Type: text/plain
            
			if res[1] == "Content-Disposition" then
				fieldname = res[2]:match('name="(%a*)"')
                -- ngx.log(ngx.INFO, 'field name: ' .. fieldname)

                -- extract file extension
                if fieldname == 'file' then
                    local filename = res[2]:match('filename="([^%"]*)"')
                    if filename then
                        self.extname = getextension(filename)
                    end
                end
			end
			
		elseif typ == "body" then -- got value of current post field
			if fieldname == "file" then
                local status, err = send_data(self, st, res)
                if not status == 200 then
                    return status, err
                end
            elseif fieldname == 'append' then
                -- `append` = group1/M00/00/02/wKgBtFY4gLGENVe2AAAAAFqCAvc165.txt
                if res then
                    ngx.log(ngx.INFO, 'append to ' .. res)
                    if not self.upload_result then
                        self.upload_result = build_upload_result_from_path(res)
                    end
                end
			end
			
		--elseif typ == "part_end" then

		elseif typ == "eof" then
			break
		end
	end

    if self.upload_result then
        return 302, '/' .. self.upload_result.group_name .. '/' .. self.upload_result.file_name
    else
        return 500, 'unknown error'
    end
end

local function headers(self, key)
    if not self.header_vars then
        self.header_vars = ngx.req.get_headers()
    end

    if key then
        return self.header_vars[key]
    else
        return self.header_vars
    end
end

-- Do the posting.
--
-- Return { http-status, content }, on success, this would be { 302, <url> },
-- otherwise, the content would be error message.
function Request:post(path)

	if ngx.req.get_method() == 'POST' then
		local header = headers(self, 'Content-Type')
        if not header then
            return 400, 'Content-Type header not set.'
        end

        if path then
            self.upload_result = build_upload_result_from_path(path)
        end

        -- content type sample:
        -- Content-Type: multipart/form-data; boundary=----WebKitFormBoundaryEt59FqhmJ380W0Rf
        ct = header:match('([^;]*)')
		ngx.log(ngx.INFO, 'Content-Type: ' .. ct)

		if ct == 'multipart/form-data' then
			return handle_multipart_formdata(self, path)
        elseif ct == 'application/octet-stream' then
            return handle_octet_stream(self)
        else
            return 400, 'Content-Type ' .. ct .. ' is not supported.'
		end
    else
        return 501, 'HTTP_METHOD_NOT_IMPLEMENTED'
	end
end

function Request:new()
	local obj = {
		header_vars = nil,
        upload_result = nil,
        extname = nil
	}

	return setmetatable(obj, { __index = Request })
end

return Request
