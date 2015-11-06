-- Copyright (C) xing_lao

local function post_to(path)
	local request = get_instance().request
	status, res = request:post(path)

    if status == 302 then
        ngx.redirect(res)
    else
        ngx.status = status
        ngx.say(res)
        ngx.exit(ngx.HTTP_OK)
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
        path = path:sub(i)
    end
    post_to(path)
end
