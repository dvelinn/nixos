{ lib, pkgs, config, ... }:

let
  cfg = config.programs.perfBalanced;
in
{
  options.programs.perfBalanced = {
    enable = lib.mkEnableOption "CachyOS-style balanced performance tuning";

    # Kernel flavor: keep stock by default, optionally use zen
    kernelFlavor = lib.mkOption {
      type = lib.types.enum [ "stock" "zen" ];
      default = "stock";
      description = "Kernel flavor to use (stock or zen).";
    };

    # CPU governor
    cpuGovernor = lib.mkOption {
      type = lib.types.enum [ "schedutil" "performance" "powersave" "ondemand" ];
      default = "schedutil";
      description = "Default CPU frequency governor.";
    };

    # ZRAM swap
    zram = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable compressed RAM swap (zram).";
      };
      percent = lib.mkOption {
        type = lib.types.ints.between 1 100;
        default = 12; # ~4 GiB on 32 GiB; good 'balanced' default
        description = "Percent of RAM to allocate for zram (compressed).";
      };
      algorithm = lib.mkOption {
        type = lib.types.enum [ "zstd" "lz4" "lzo" ];
        default = "zstd";
        description = "Compression algorithm used by zram.";
      };
      priority = lib.mkOption {
        type = lib.types.int;
        default = 100;
        description = "Swap priority for zram (higher = used first).";
      };
      swappiness = lib.mkOption {
        type = lib.types.int;
        default = 80; # balanced: prefer zram before OOM, but not overly swappy
        description = "vm.swappiness value.";
      };
    };

    # Transparent Huge Pages
    thpMode = lib.mkOption {
      type = lib.types.enum [ "always" "madvise" "never" ];
      default = "madvise";
      description = "Transparent Huge Pages policy.";
    };

    # Networking
    net = {
      qdisc = lib.mkOption {
        type = lib.types.enum [ "fq_codel" "fq" "cake" ];
        default = "fq_codel"; # widely supported, low-latency default
        description = "Default queuing discipline for network interfaces.";
      };
      congestionControl = lib.mkOption {
        type = lib.types.enum [ "bbr" "cubic" "bbr2" ];
        default = "bbr";
        description = "TCP congestion control algorithm.";
      };
    };

    # I/O scheduler rules per device type
    io = {
      ssdScheduler = lib.mkOption {
        type = lib.types.enum [ "none" "mq-deadline" "bfq" "kyber" ];
        default = "none"; # modern NVMe recommends 'none'
        description = "I/O scheduler to set for non-rotational devices.";
      };
      hddScheduler = lib.mkOption {
        type = lib.types.enum [ "mq-deadline" "bfq" "kyber" ];
        default = "mq-deadline"; # balanced default for HDDs
        description = "I/O scheduler to set for rotational devices.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    #### Kernel flavor
    boot.kernelPackages = lib.mkIf (cfg.kernelFlavor == "zen") pkgs.linuxPackages_zen;

    #### CPU governor (applies on boot)
    powerManagement.cpuFreqGovernor = cfg.cpuGovernor;

    #### ZRAM swap & VM tuning
    zramSwap = lib.mkIf cfg.zram.enable {
      enable = true;
      algorithm = cfg.zram.algorithm;
      memoryPercent = cfg.zram.percent;
      priority = cfg.zram.priority;
    };

    boot.kernel.sysctl = {
      "vm.swappiness" = cfg.zram.swappiness;

      # THP policy
      "vm.transparent_hugepage.enabled" = cfg.thpMode;

      # Networking: queueing discipline + congestion control
      "net.core.default_qdisc" = cfg.net.qdisc;
      "net.ipv4.tcp_congestion_control" = cfg.net.congestionControl;

      # Play well with zram in balanced mode
      "vm.page-cluster" = 0;      # better behavior for zram (less swap readahead)
    };

    #### I/O scheduler udev rule (sets per-device on hotplug)
    services.udev.extraRules = ''
      # SSDs / NVMe (non-rotational)
      ACTION=="add|change", SUBSYSTEM=="block", KERNEL=="sd[a-z]" , ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="${cfg.io.ssdScheduler}"
      ACTION=="add|change", SUBSYSTEM=="block", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/scheduler}="${cfg.io.ssdScheduler}"

      # HDDs (rotational)
      ACTION=="add|change", SUBSYSTEM=="block", KERNEL=="sd[a-z]" , ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="${cfg.io.hddScheduler}"
    '';

    #### Helpful notes:
    # - This profile does NOT set up hibernation; add disk-backed swap if you want that.
    # - 'cake' qdisc requires the sch_cake module; fq_codel is the most compatible default.
  };
}
