function install_luarock_packages() {
    package_list=""
    for rocks_file in $@; do
        package_list=$(printf "%s\n%s" "$package_list" "$(cat $rocks_file)")
    done
    IFS=$'\n'
    for package in $package_list; do
        package_name=""
        package_version=""
        if [[ "$package" != "" ]]; then
            package_name=$(echo $package | egrep -o "^[^ ]+" | egrep -o "[^ ]+")
            package_version=$(echo $package | egrep -o "\s+[^ ]+$" | egrep -o "[^ ]+")
            # package_name=$(echo $package | cut -d' ' -f1)
            # package_version=$(echo $package | cut -d' ' -f2)
            printf "luarocks install $package_name $package_version\n"
            luarocks install $package_name $package_version
            if [[ "$?" != "0" ]]; then
                printf "installation of package $package_name $package_version failed\n"
                exit 1
            fi
        fi
    done
}

function main() {
    install_luarock_packages $@
    exit $?
}

main $@