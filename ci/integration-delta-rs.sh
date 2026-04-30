#!/usr/bin/env bash
FLAVOR=$1

set -eau pipefail

if [ -d delta-rs ]; then
  rm -rf delta-rs
fi;

git clone --depth 1 --branch buoyant/main https://git.buoyantdata.com/delta-io/delta-rs

pushd delta-rs

cat >> Cargo.toml <<EOF
[patch.crates-io]
delta_kernel = { package = "buoyant_kernel", path = "../kernel" }
EOF

## Ensure the local dependencies are there.
gmake setup-dat
echo ">> Integration flavor ${FLAVOR}"

if [ "${FLAVOR}" = "python" ]; then
  gmake -C python develop
  set +e
  grep "avx2" /proc/cpuinfo > /dev/null
  if [ $? -ne 0 ]; then
    # Some of the machines in the cluster may not have some CPU instructions that
    # polars is compiled against
    (source python/.venv/bin/activate && uv pip install "polars[rtcompat]==1.39")
  fi
  set -e
  gmake -C python unit-test
else
  # Run the integration tests
  cargo build
  cargo nextest r
  cargo nextest r --features datafusion
fi;

