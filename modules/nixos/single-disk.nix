# One disk: an EFI system partition and a root, ext4 by default. disko partitions and
# formats it at install; after that it only declares the mounts. A host whose disk isn't
# nvme0n1 sets disko.devices.disk.main.device.
#
# A host can choose another root filesystem, for example XFS for yonder's reflink clones:
#
#   disko.devices.disk.main.content.partitions.root.content.format = "xfs";
#
# The format applies only at install. Set it in the commit that the box is installed from.
# A box that gets a format other than the one on its disk does not boot.
{ inputs, lib, ... }: {
  imports = [ inputs.disko.nixosModules.disko ];

  disko.devices.disk.main = {
    device = lib.mkDefault "/dev/nvme0n1";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = lib.mkDefault "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
