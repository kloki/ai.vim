local M = {}

local config = require("_ai/config")

local function exec(cmd, args, on_complete)
	local stdout = vim.loop.new_pipe()
	local stdout_chunks = {}
	local function on_stdout_read(_, data)
		if data then
			table.insert(stdout_chunks, data)
		end
	end

	local stderr = vim.loop.new_pipe()
	local stderr_chunks = {}
	local function on_stderr_read(_, data)
		if data then
			table.insert(stderr_chunks, data)
		end
	end

	-- print(cmd, vim.inspect(args))

	local handle

	handle, error = vim.loop.spawn(cmd, {
		args = args,
		stdio = { nil, stdout, stderr },
	}, function(code)
		stdout:close()
		stderr:close()
		handle:close()

		vim.schedule(function()
			if code ~= 0 then
				on_complete(vim.trim(table.concat(stderr_chunks, "")))
			else
				on_complete(nil, vim.trim(table.concat(stdout_chunks, "")))
			end
		end)
	end)

	if not handle then
		on_oncomplete(cmd .. " could not be started: " .. error)
	else
		stdout:read_start(on_stdout_read)
		stderr:read_start(on_stderr_read)
	end
end

local function request(body, on_complete)
	local api_key = os.getenv("OPENAI_API_KEY")
	if not api_key then
		on_complete({}, "$OPENAI_API_KEY environment variable must be set")
		return
	end

	local curl_args = {
		"--silent",
		"--show-error",
		"--no-buffer",
		"--max-time",
		config.timeout,
		"-L",
		"https://api.openai.com/v1/chat/completions",
		"-H",
		"Authorization: Bearer " .. api_key,
		"-X",
		"POST",
		"-H",
		"Content-Type: application/json",
		"-d",
		vim.json.encode(body),
	}

	exec("curl", curl_args, on_complete)
end

function M.ask(prompt, on_complete)
	body = {
		model = config.model,
		temperature = config.temperature,
		messages = { [1] = { role = "user", content = prompt } },
	}
	request(body, on_data, on_complete)
end

function M.edit(prompt, selected_text, on_complete)
	body = {
		model = config.model,
		temperature = config.temperature,
		messages = { [1] = { role = "user", content = prompt .. "\n```" .. selected_text .. "```" } },
	}
	request(body, on_complete)
end

return M
