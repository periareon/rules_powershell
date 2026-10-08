# A failing `using module` statement is a parse failure of the whole script.
using module ThisModuleDoesNotExist

Write-Output "never reached"
