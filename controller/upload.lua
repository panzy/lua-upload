-- Copyright (C) xing_lao
function background()
	local request = get_instance().request
	status, res = request:post()

    if status == 302 then
        ngx.redirect(res)
    else
        ngx.status = status
        ngx.say(res)
        ngx.exit(ngx.HTTP_OK)
    end
end
