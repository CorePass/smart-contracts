// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {AccessControl} from "./utils/AccessControl.sol";

contract NameService is AccessControl {
    struct Service {
        string name;
        string image;
        address addr;
    }

    Service[] private services;

    event ServiceAdded(string name, string image, address addr);
    event ServiceRemoved(string name, string image, address addr);

    function addService(
        string memory _name,
        string memory _image,
        address _addr
    ) external onlyAdmin {
        services.push(Service(_name, _image, _addr));

        emit ServiceAdded(_name, _image, _addr);
    }

    function removeService(uint256 _index) external onlyAdmin {
        require(_index < services.length, "NameService: invalid index");

        Service memory service = services[_index];

        services[_index] = services[services.length - 1];
        services.pop();

        emit ServiceRemoved(service.name, service.image, service.addr);
    }

    function getServices()
        external
        view
        returns (
            string[] memory,
            string[] memory,
            address[] memory
        )
    {
        string[] memory names = new string[](services.length);
        string[] memory images = new string[](services.length);
        address[] memory addresses = new address[](services.length);

        for (uint256 i = 0; i < services.length; i++) {
            names[i] = services[i].name;
            images[i] = services[i].image;
            addresses[i] = services[i].addr;
        }

        return (names, images, addresses);
    }
}
