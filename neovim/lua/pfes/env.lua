local function islinux()
    local home = vim.fn.expand("$HOME")

    return string.sub(home, 1, #home) == "/home" or nil
end

local function gethome()
    return vim.fn.expand("$HOME") or vim.fn.expand("USERPROFILE")
end

return {
    islinux = islinux(),
    home = gethome()
}
