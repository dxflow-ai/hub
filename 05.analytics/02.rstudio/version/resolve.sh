# RStudio Server announces its current build through the IDE's own update check.
# The deb is named with a - where the build metadata carries a +.

echo "VERSION=$(fetch 'https://www.rstudio.org/links/check_for_update?version=0.0.0' |
    tr '&' '\n' | sed -n 's/^update-version=//p' | sed 's/%2B/-/' | head -1)"
