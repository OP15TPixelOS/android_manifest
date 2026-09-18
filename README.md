# PixelOS

## Getting Started

To get started with the PixelOS source code, you'll need to be
familiar with [Git and Repo](https://source.android.com/setup/build/downloading).

To initialize your local repository, run:

```bash
repo init -u https://github.com/PixelOS-AOSP/android_manifest.git -b seventeen --git-lfs
```

Then, sync the repository:

```bash
repo sync
```

## OnePlus 15T (fairlady)

Use the device manifest for the fairlady PixelOS 17 tree:

```bash
repo init -u https://github.com/OP15TPixelOS/android_manifest.git -b seventeen -m fairlady.xml --git-lfs
repo sync
```

The `patches/` directory contains reproducible diffs for the AOD and haptic
changes. The corresponding source repositories should be checked out at the
same revisions before applying them.

## Building the System

Initialize the ROM build environment by sourcing the envsetup.sh script:

```bash
source build/envsetup.sh
```

After cloning the device-specific sources, use breakfast to configure the build for your device:

```bash
breakfast devicecodename
```

Start the compilation:

```bash
m pixelos
```

## Submitting Patches
Patches are always welcome! Feel free to submit your patches via [PixelOS Gerrit](https://review.pixelos.net/).
