#!/bin/bash
var_dir_root=$(dirname $(realpath $0))/../../
pushd ${var_dir_root}
    tree tok -I pyproject.toml -I uv.lock -I README.md -I scripts
popd