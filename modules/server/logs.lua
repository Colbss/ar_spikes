

-- https://coxdocs.dev/ox_lib/Modules/Logger/Server

function CreateLog(src, action, message, tags)
    --print(string.format("[LOG] Action: %s | Message: %s | Tags: %s", action, message, json.encode(tags)))
    lib.logger(src, action, message, tags)
end