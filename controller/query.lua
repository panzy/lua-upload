-- Copyright (C) xing_lao

-- Query file info.
function index()
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
