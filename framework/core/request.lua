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

-- Do the uploading work with multipart/form-data,
-- return { http-status, content }.
local function handle_multipart_formdata(self, path)
	local form, err = resty_upload:new(config.chunk_size)
	if not form then
        return 500, err
	end
	form:set_timeout(recieve_timeout)
	
	local fieldname
    local upload_result
    local st = init_storage()

    if not st then
        return 500, 'cannot to connect to file storage service'
    end

    if path then
        upload_result = build_upload_result_from_path(path)
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
                if not upload_result then
                    -- ngx.log(ngx.INFO, 'init uploading ' .. self.extname)
                    upload_result, err = st:upload_appender_by_buff(res, self.extname)
                    if not upload_result then
                        return 500, "upload(init) error: " .. err
                    end
                else
                    --ngx.log(ngx.INFO, 'append to /' .. upload_result.group_name .. '/' .. upload_result.file_name)
                    local append_result, err = st:append_by_buff(upload_result.group_name, upload_result.file_name, res)
                    if not append_result then
                        return 500, "upload(append) error: " .. err
                    end
                end
            elseif fieldname == 'append' then
                -- `append` = group1/M00/00/02/wKgBtFY4gLGENVe2AAAAAFqCAvc165.txt
                if res then
                    ngx.log(ngx.INFO, 'append to ' .. res)
                    if not upload_result then
                        upload_result = build_upload_result_from_path(res)
                    end
                end
			end
			
		--elseif typ == "part_end" then

		elseif typ == "eof" then
			break
		end
	end

    if upload_result then
        return 302, '/' .. upload_result.group_name .. '/' .. upload_result.file_name
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
        -- content type sample:
        -- Content-Type: multipart/form-data; boundary=----WebKitFormBoundaryEt59FqhmJ380W0Rf
        ct = header:match('([^;]*)')
		ngx.log(ngx.INFO, 'Content-Type: ' .. ct)
		if ct == 'multipart/form-data' then
			return handle_multipart_formdata(self, path)
        else
            return 400, 'Content-Type ' .. ct .. ' is not supported.'
		end
    else
        return 501, 'HTTP_METHOD_NOT_IMPLEMENTED'
	end
end

function Request:new()
	local obj = {
		header_vars = nil
	}

	return setmetatable(obj, { __index = Request })
end

return Request
