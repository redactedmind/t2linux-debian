# INFOS

this file contains all the reasoning and possible decisions that were made during development of this project (to be rewritten and to be fed in an LLM to convey better all the things)



the containerized scripts are 

the buildah instead of dockerfile approach is used because it's:
- still cross-containerization platform (works with podman and docker) if done right
- has better cache invalidation
- lets easily implement control flow, thus:
  - lets you build the right container for your applications

first let's implement debian targets only (target operating system/distro)


make a raw build script (so can be built directlty on host or in a vm or in lxc/lxd)

containerized script is started by the user, it sets up the environment and then starts inside the container that same raw buld script
thus we avoid maintaining mutliple build scripts for same thing

the same reasoning that lead us to use buildah instead of dockerfiles


the idea is to build the kernel for a target system on the target itself, so debian bookworm target will use debian bookworm host (container) and the bookworm linux kernel (src and/or patches).

there should be a version for using on-system buildah if user has one (command -v)


main feature:
- pause builds and continue them (ability to debug and inspect), but without penalty in portability like may be with bind mounts

add an option for building the latest version (may result unstable), or use a well known version

xanmod and debian are not forks of linux, are just number of patches and configurations applied to linux source code

elevation from sh to bash is intentional (has better functionality), as also the use of sh (it is more widespread and can be considered cross-platform)
## Questions

### Bind Mounts?


### Ubuntu?

