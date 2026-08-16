local text = io.read("*a")
text = text:gsub("enum%s+struct%s+", "struct /*__SP_ENUM_STRUCT__*/ ")
text = text:gsub("methodmap%s+", "class /*__SP_METHODMAP__*/ ")

local cmd = { "clang-format" }
for i = 1, #arg do table.insert(cmd, arg[i]) end

local stdout = vim.fn.system(cmd, text)
stdout = stdout:gsub("struct%s+/%*__SP_ENUM_STRUCT__%*/%s+", "enum struct ")
stdout = stdout:gsub("class%s+/%*__SP_METHODMAP__%*/%s+", "methodmap ")
io.write(stdout)
