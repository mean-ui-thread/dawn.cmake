[![LICENSE](https://img.shields.io/badge/License-MIT-0298c3.svg)](https://opensource.org/licenses/MIT) [![Build Status](https://travis-ci.com/mchiasson/dawn.cmake.svg?branch=master)](https://travis-ci.com/mchiasson/dawn.cmake)

# dawn.cmake
Google Dawn cmake build scripts with no ties to GN and depot_tools.

## Build dependencies
-   [cmake 3.2+](https://cmake.org/)
-   [Python 2.7+](https://python.org/)
-   [Python 3.6+](https://python.org/)

### Linux
```sh
sudo apt update
sudo apt install git cmake python2.7 python3 build-essential libgl1-mesa-dev libvulkan-dev mesa-common-dev
```

## How to build

First, checkout recursively in order to get the required git submodules
```sh
git clone https://github.com/mchiasson/dawn.cmake --recursive
```
or
```sh
git clone https://github.com/mchiasson/dawn.cmake
cd dawn.cmake
git submodule update --init --recursive
```

and then build
```sh
cmake -S ./dawn.cmake -B ./build-dawn.cmake-Release -DCMAKE_BUILD_TYPE=Release
cmake --build ./build-dawn.cmake-Release
```

## :heart: Sponsor us :heart:

[![Donate to this project using Patreon](https://img.shields.io/badge/Patreon-donate-yellow.svg)](https://www.patreon.com/mattchiasson)
[![Donate to this project using Flattr](https://img.shields.io/badge/Flattr-donate-yellow.svg)](https://flattr.com/@mattchiasson)
[![Donate to this project using Liberapay](https://img.shields.io/badge/Liberapay-donate-yellow.svg)](https://liberapay.com/MattChiasson/donate)
[![Donate to this project using Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-donate-yellow.svg)](https://www.buymeacoffee.com/MYO5mfJhL)

## Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our process for submitting pull requests to us, and read [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for details on our code of conduct.


## Authors

-   **Mathieu-André Chiasson** - *Initial work* - [mchiasson](https://github.com/mchiasson)

See also the list of [contributors](https://github.com/mchiasson/dawn.cmake/contributors) who participated in this project.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details

