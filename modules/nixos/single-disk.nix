# One disk: an EFI system partition and an ext4 root. disko partitions and formats it at
# install; after that it only declares the mounts. A host whose disk isn't nvme0n1 sets
# disko.devices.disk.main.device.
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
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
