-- Copyright (C) xing_lao

local function post_to(path)
	local request = get_instance().request

    co = coroutine.create(function(path)
        return request:post(path)
    end)

    local ok, status, res = coroutine.resume(co, path)

    ngx.log(ngx.INFO, 'coroutine yielded: ', ok, ' ', status, ' ', res)
    if ok then
        ngx.status = status
        ngx.say(res)
        ngx.flush()
        ok, status, res = coroutine.resume(co, status, res)

        if status == 200 then
            status, info = request:query_file_info(res)
            if info then
                local cjson = require "cjson"
                ngx.say(cjson.encode(info))
            end
        end
    else
        ngx.status = status
        ngx.say(res)
    end
end

function index()
    post_to(nil)
end

-- Append to existing file.
-- 
-- HTTP raw header sample:
-- POST /upload/append/group1/M00/00/02/wKgBtFY8BW2ETBr0AAAAAFqCAvc159.txt HTTP/1.0
function append()
    path = ngx.req.raw_header():match('^POST (.*) HTTP/')

    -- trim controller & action name from path
    --
    -- /upload/append/group1/M00/00/02/wKgBtFY8BW2ETBr0AAAAAFqCAvc159.txt
    -- => /group1/M00/00/02/wKgBtFY8BW2ETBr0AAAAAFqCAvc159.txt
    --
    -- note that there is a URL rewritting allowing omitting the action name:
    -- /upload/group1/M00/00/02/wKgBtFY8BW2ETBr0AAAAAFqCAvc159.txt
    -- ==url-rewrite==>
    -- /upload/append/group1/M00/00/02/wKgBtFY8BW2ETBr0AAAAAFqCAvc159.txt

    i, _ = path:find('/group')
    if i then
        post_to(path:sub(i))
    else
        post_to(nil)
    end
end

-- Query file info.
function query()
    path = ngx.req.raw_header():match('^%a+ (.*) HTTP/')
    i, _ = path:find('/group')
    if i then
        fileid = path:sub(i + 1)

        local request = get_instance().request
        status, info = request:query_file_info(fileid)
        ngx.status = status
        if info then
            local cjson = require "cjson"
            ngx.say(cjson.encode(info))
        end
        ngx.exit(ngx.HTTP_OK)
    else
        ngx.status = 400
    end
end
