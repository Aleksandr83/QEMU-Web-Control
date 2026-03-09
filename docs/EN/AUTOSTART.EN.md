# Virtual Machine Autostart

## Overview

The autostart feature automatically starts selected virtual machines when the Linux system boots.

## Setup

### 1. Mark VM for Autostart

In the web interface when creating or editing a virtual machine:
1. Open the VM create/edit form
2. Check **"Start automatically when system boots"**
3. Save changes

### 2. Install Autostart Service

```bash
# In Russian
./scripts/autostart-service.sh --install --lang ru

# In English
./scripts/autostart-service.sh --install
```

The service will automatically:
- Create systemd unit file
- Configure Docker dependency
- Enable automatic start on boot

### 3. Check Service Status

```bash
./scripts/autostart-service.sh --status --lang ru
```

or directly via systemd:

```bash
sudo systemctl status qemu-autostart.service
```

## Usage

### Manual Autostart

Start all VMs with autostart enabled manually:

```bash
docker compose exec app php artisan vm:autostart
```

or via the service:

```bash
sudo systemctl start qemu-autostart.service
```

### Check List of VMs with Autostart

Go to the web interface:
- VMs with autostart are marked with a blue clock icon ⏰
- In the virtual machine list you can see which VMs will start automatically

## Service Management

### Enable Service

```bash
sudo systemctl enable qemu-autostart.service
```

### Disable Service

```bash
sudo systemctl disable qemu-autostart.service
```

### Start Service Manually

```bash
sudo systemctl start qemu-autostart.service
```

### Stop Service

```bash
sudo systemctl stop qemu-autostart.service
```

### Remove Service

```bash
./scripts/autostart-service.sh --uninstall --lang ru
```

## Logs

### View Service Logs

```bash
sudo journalctl -u qemu-autostart.service
```

### View Recent Logs

```bash
sudo journalctl -u qemu-autostart.service -n 50
```

### Follow Logs in Real Time

```bash
sudo journalctl -u qemu-autostart.service -f
```

## Troubleshooting

### Service Won't Start

1. Check if Docker is running:
```bash
sudo systemctl status docker
```

2. Check if application containers are running:
```bash
docker compose ps
```

3. Check service logs:
```bash
sudo journalctl -u qemu-autostart.service -n 100
```

### VMs Don't Start Automatically

1. Make sure the VM has autostart enabled in the web interface

2. Check VM status manually:
```bash
docker compose exec app php artisan vm:autostart
```

3. Check VM disk permissions:
```bash
ls -la /var/lib/qemu/vms/
```

### Service Starts But Nothing Happens

Make sure at least one VM has autostart enabled:
```bash
docker compose exec app php artisan tinker
>>> \App\Models\VirtualMachine::where('autostart', true)->get();
```

## Examples

### Example 1: Development Server

You have a VM with a database that should always be available:

1. Create VM "Development Database"
2. Enable autostart
3. Install autostart service
4. On each server reboot the VM will start automatically

### Example 2: Test Environment

Several VMs for testing that are always needed:

1. Create VMs: "Test Web Server", "Test DB", "Test Cache"
2. Enable autostart for all three
3. On system boot all three VMs will start automatically

### Example 3: Selective Autostart

You have 10 VMs but only 2 need to run automatically:

1. Create all 10 VMs
2. Enable autostart only for the 2 needed
3. Start the other 8 manually as needed

## Technical Details

### How It Works

1. On system boot systemd starts
2. After Docker starts, `qemu-autostart.service` runs
3. The service executes `php artisan vm:autostart`
4. The command finds all VMs with `autostart = true` and status `stopped`
5. For each VM it calls `QemuService::start()`
6. VMs start sequentially

### Service File

Location: `/etc/systemd/system/qemu-autostart.service`

```ini
[Unit]
Description=QEMU Web Control - Autostart Virtual Machines
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/path/to/QemuWebControl
ExecStart=/usr/bin/docker compose exec -T app php artisan vm:autostart
User=your-username
Group=your-group

[Install]
WantedBy=multi-user.target
```

### Artisan Command

Command: `php artisan vm:autostart`

Source: `app/Console/Commands/AutostartVirtualMachines.php`

Logic:
1. Finds all VMs where `autostart = true` and `status = stopped`
2. Calls `QemuService::start()` for each VM
3. Logs results (success/failure)
4. Updates VM status in database

## Recommendations

### Security

- Don't enable autostart for all VMs - this increases system boot time
- Ensure VMs have enough resources (CPU, RAM) on the host
- Check logs after system reboot

### Performance

- Starting multiple VMs at once can be resource-intensive
- Consider sequential startup with delays (modify the command)
- Monitor host resource usage

### Reliability

- Regularly check service status
- Set up monitoring for critical VMs
- Have a VM disk backup plan

## FAQ

**Q: Can I configure VM startup order?**  
A: In the current version VMs start in order of their ID. To change order, modify the `vm:autostart` command.

**Q: What if a VM doesn't start during autostart?**  
A: The service continues, but the VM remains in `stopped` status. Check logs for diagnostics.

**Q: How long does autostart take?**  
A: Depends on the number of VMs and system resources. Usually 2-5 seconds per VM.

**Q: Can VMs be automatically stopped on shutdown?**  
A: Not in the current version, but Docker will stop containers, which will stop the VMs.

**Q: Does autostart work in Docker Swarm/Kubernetes?**  
A: Current implementation is for docker-compose. Orchestrators would need adaptation.

## Support

If you have issues:
1. Check logs: `sudo journalctl -u qemu-autostart.service`
2. Check Docker status: `sudo systemctl status docker`
3. Run command manually: `docker compose exec app php artisan vm:autostart`
4. Check permissions for `/var/lib/qemu/vms/`
