local function islinux()
    local home = vim.fn.expand("$HOME")

    return string.sub(home, 1, #home) == "/home" or nil
end

return {
    islinux = islinux()
}
