#!/usr/bin/env bash

get_product_soc() {
    curl -s "https://gate.radxa.com/https://raw.githubusercontent.com/RadxaOS-SDK/rsdk/main/src/share/rsdk/configs/products.json" | \
    jq -r ".[] | select(.product == \"$(rsetup get_product_id)\").soc"
}

checks() {
    check_dkms_status
    system_upgrade
}

check_dkms_status() {
    if [[ "$(dkms status | awk '{print $5}' | grep -v installed)" == "" ]]
    then
        echo "DKMS is ready."
    else
        echo "Some dkms modules are not installed, please check "dkms status""
        return 1
    fi
}

process_source() {
    local original="$1" list="$2"
    IFS="|" read -r -a list <<< "$list"
    list[0]="${list[0]//$original/$TARGET_RELEASE}"
    list[5]="${list[2]//$original/$TARGET_RELEASE}"
    list[6]="${list[3]//$original/$TARGET_RELEASE}"

    if grep -q "radxa-archive-keyring.gpg" <<< "${list[1]}" && grep -q "rockchip-" <<< "${list[6]}" && grep -q "rk3588" <<< "$(get_product_soc)"
    then
        list[5]="${list[5]//$TARGET_RELEASE/$(get_product_soc)-$TARGET_RELEASE}"
        list[6]="${list[6]//rockchip/$(get_product_soc)}"
        list[0]="/etc/apt/sources.list.d/80-$(basename "${list[0]}")"
    elif grep -q "radxa-archive-keyring.gpg" <<< "${list[1]}" && grep -q "rockchip-" <<< "${list[6]}" && grep -e "rk3582" <<< "$(get_product_soc)"
    then
        list[5]="${list[5]//$TARGET_RELEASE/rk3582-$TARGET_RELEASE}"
        list[6]="${list[6]//rockchip/rk3582}"
        list[0]="/etc/apt/sources.list.d/80-$(basename "${list[0]}")"
    fi

    if grep -q "radxa-archive-keyring.gpg" <<< "${list[1]}" && [[ "${list[6]}" == "$TARGET_RELEASE" ]]
    then
        list[0]="/etc/apt/sources.list.d/70-$(basename "${list[0]}")"
    fi

    if grep -q "/debian" <<< "${list[2]}" && grep -e "$TARGET_RELEASE" <<< "${list[6]}"
    then
        if [[ "${list[6]}" == "$TARGET_RELEASE" ]]
        then
            list[0]="/etc/apt/sources.list.d/$TARGET_RELEASE.list"
        fi
        list[0]="/etc/apt/sources.list.d/50-$(basename "${list[0]}")"
    fi

    echo "${list[0]}|${list[1]}|${list[2]}|${list[3]}|${list[4]}|${list[5]}|${list[6]}"
}

setup_source() {
    IFS="|" read -r -a list <<< "${SOURCE_LISTS[RTUI_MENU_SELECTED_INDEX]}"
    item="$(inputbox "Original URL is ""${list[2]}"", Please input the new URL:" "${list[5]}")"
    list[5]="$item"
    item="$(inputbox "Original dist is ""${list[3]}"", Please input the new dist:" "${list[6]}")"
    list[6]="$item"
    SOURCE_LISTS[RTUI_MENU_SELECTED_INDEX]="${list[0]}|${list[1]}|${list[2]}|${list[3]}|${list[4]}|${list[5]}|${list[6]}"
}

save_source_list() {
    for list in "${SOURCE_LISTS[@]}"
    do
        IFS="|" read -r -a list <<< "$list"
        if ! curl -Lsqf "${list[5]}/dists/${list[6]}/Release" -o /dev/null
        then
            msgbox "Can't access ${list[5]}/dists/${list[6]}/Release, please check the URL and dist."
            return
        fi
    done

    if [[ -e /etc/apt/sources.list ]]
    then
        mv /etc/apt/sources.list /etc/apt/sources.list.bak
    fi

    for source in /etc/apt/sources.list.d/*.list
    do
        mv "$source" "$source.bak"
    done

    for list in "${SOURCE_LISTS[@]}"
    do
        IFS="|" read -r -a list <<< "$list"
        echo "deb ${list[1]} ${list[5]} ${list[6]} ${list[4]}" > "${list[0]}"
    done
    msgbox "Source list saved."
}

system_upgrade() {
    rsetup system_update
}
