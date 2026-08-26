import React from "react";
import { CodeBlock, DiagramBlock } from "lavish-axi/components";

const commands = `# Provisioning layer
make tf-init
make tf-plan
make tf-apply

# Host and role-specific configuration
make ansible-host WIPE_CONFIRM=true
make ansible-infra
make ansible-erp
make ansible-utility
make ansible-website
make ansible-build-thud
make ansible-build-scarthgap
make ansible-build-brimstone

# Manual legacy import (not part of normal Terraform/Ansible guest flow)
make ise7-import DRY_RUN=1
make ise7-import`;

const css = `
  :root {
    color-scheme: dark;
    --bg: #07111f;
    --surface: #0d1b2a;
    --surface-2: #12263a;
    --line: #29445f;
    --text: #eef6ff;
    --muted: #b7cadc;
    --accent: #63d3ff;
    --accent-2: #8ff0c5;
    --warn: #ffd27a;
    --danger: #ff9c9c;
  }
  * { box-sizing: border-box; }
  html { scroll-behavior: smooth; background: var(--bg); }
  body { margin: 0; background: var(--bg); color: var(--text); font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; line-height: 1.65; }
  a { color: var(--accent); text-underline-offset: 3px; }
  code { color: #d9f5ff; background: #071827; border: 1px solid #25445d; border-radius: .35rem; padding: .08rem .32rem; overflow-wrap: anywhere; }
  .page { width: min(1180px, calc(100% - 32px)); margin: 0 auto; padding: 32px 0 80px; }
  .hero { padding: clamp(28px, 6vw, 72px); border: 1px solid #326080; border-radius: 24px; background: radial-gradient(circle at 88% 12%, rgba(99,211,255,.18), transparent 32%), linear-gradient(145deg, #10263a, #081523 65%); box-shadow: 0 24px 70px rgba(0,0,0,.28); }
  .eyebrow { margin: 0 0 12px; color: var(--accent-2); font: 700 .8rem/1.2 ui-monospace, SFMono-Regular, Menlo, monospace; letter-spacing: .12em; text-transform: uppercase; }
  h1 { margin: 0; max-width: 900px; font-size: clamp(2.2rem, 5vw, 4.7rem); line-height: 1.03; letter-spacing: -.045em; }
  .lede { max-width: 880px; margin: 24px 0 0; color: #d3e5f2; font-size: clamp(1.05rem, 2vw, 1.3rem); }
  .pills { display: flex; flex-wrap: wrap; gap: 10px; margin-top: 28px; }
  .pill { display: inline-flex; align-items: center; min-height: 32px; padding: 5px 11px; border: 1px solid #3d6683; border-radius: 999px; background: rgba(4,20,33,.65); color: #def5ff; font-size: .87rem; font-weight: 700; }
  .notice { margin-top: 20px; padding: 16px 18px; border: 1px solid #806c35; border-left: 4px solid var(--warn); border-radius: 12px; background: #221d10; color: #fff0c9; }
  nav { position: sticky; top: 12px; z-index: 5; display: flex; gap: 8px; margin: 20px 0 0; padding: 10px; overflow-x: auto; border: 1px solid var(--line); border-radius: 14px; background: rgba(7,17,31,.93); backdrop-filter: blur(16px); }
  nav a { flex: 0 0 auto; padding: 7px 11px; border-radius: 8px; color: var(--muted); font-size: .86rem; font-weight: 700; text-decoration: none; }
  nav a:hover { background: var(--surface-2); color: white; }
  section { scroll-margin-top: 90px; margin-top: 56px; min-width: 0; }
  .section-head { display: grid; grid-template-columns: minmax(0, 1fr); gap: 8px; margin-bottom: 20px; }
  .kicker { margin: 0; color: var(--accent-2); font: 700 .78rem/1.3 ui-monospace, SFMono-Regular, Menlo, monospace; letter-spacing: .11em; text-transform: uppercase; }
  h2 { margin: 0; font-size: clamp(1.7rem, 3.4vw, 2.75rem); line-height: 1.12; letter-spacing: -.03em; }
  h3 { margin: 0 0 8px; font-size: 1.18rem; line-height: 1.3; }
  p { margin: 0 0 1rem; }
  .muted { color: var(--muted); }
  .stats { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 12px; margin-top: 18px; }
  .stat { min-width: 0; padding: 18px; border: 1px solid var(--line); border-radius: 14px; background: var(--surface); }
  .stat strong { display: block; color: white; font-size: 1.75rem; line-height: 1; }
  .stat span { display: block; margin-top: 8px; color: var(--muted); font-size: .88rem; }
  .grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 14px; }
  .card { min-width: 0; padding: 20px; border: 1px solid var(--line); border-radius: 16px; background: var(--surface); }
  .card.accent { border-color: #397a91; background: linear-gradient(145deg, #102839, #0c1a28); }
  .card.warn { border-color: #6c5a2d; background: #1d1a12; }
  .card p:last-child, .card ul:last-child { margin-bottom: 0; }
  ul, ol { margin: .5rem 0 1rem; padding-left: 1.35rem; }
  li { margin: .35rem 0; }
  .table-wrap { width: 100%; overflow-x: auto; border: 1px solid var(--line); border-radius: 16px; background: var(--surface); }
  table { width: 100%; min-width: 980px; border-collapse: collapse; font-size: .9rem; }
  th, td { padding: 12px 14px; border-bottom: 1px solid #213a51; text-align: left; vertical-align: top; }
  th { position: sticky; top: 0; background: #14283b; color: #dff7ff; font-size: .76rem; letter-spacing: .06em; text-transform: uppercase; }
  tr:last-child td { border-bottom: 0; }
  tbody tr:hover { background: #102236; }
  .tag { display: inline-block; margin: 2px 3px 2px 0; padding: 2px 7px; border: 1px solid #3c6078; border-radius: 999px; color: #ccecff; font-size: .72rem; white-space: nowrap; }
  .tag.manual { border-color: #7c6741; color: #ffe0a2; }
  .diagram-shell { min-width: 0; padding: 12px; border: 1px solid var(--line); border-radius: 18px; background: #f7f9fb; overflow: hidden; }
  .diagram-shell code { color: inherit; }
  .lavish-code-block pre.shiki .line span[style*="#6A737D"] { color: #a9bdcf !important; }
  .flow-list { counter-reset: flow; display: grid; gap: 12px; padding: 0; list-style: none; }
  .flow-list li { counter-increment: flow; position: relative; min-height: 62px; margin: 0; padding: 14px 16px 14px 62px; border: 1px solid var(--line); border-radius: 14px; background: var(--surface); }
  .flow-list li::before { content: counter(flow); position: absolute; left: 16px; top: 14px; display: grid; place-items: center; width: 30px; height: 30px; border: 1px solid #4fa1bd; border-radius: 50%; color: #bff2ff; font-weight: 800; }
  .flow-list strong { color: white; }
  .boundary { display: grid; grid-template-columns: 180px minmax(0, 1fr); gap: 18px; padding: 18px 0; border-top: 1px solid var(--line); }
  .boundary:first-child { border-top: 0; }
  .boundary h3 { color: var(--accent-2); }
  .source-list { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 10px; }
  .source { min-width: 0; padding: 14px 16px; border: 1px solid var(--line); border-radius: 12px; background: #0b1927; }
  .source code { display: block; width: fit-content; max-width: 100%; margin-bottom: 6px; }
  .small { font-size: .88rem; }
  .footer { margin-top: 56px; padding-top: 22px; border-top: 1px solid var(--line); color: var(--muted); font-size: .88rem; }
  @media (max-width: 820px) {
    .page { width: min(100% - 20px, 1180px); padding-top: 10px; }
    .hero { padding: 28px 20px; border-radius: 18px; }
    .stats, .grid, .source-list { grid-template-columns: 1fr; }
    .boundary { grid-template-columns: 1fr; gap: 4px; }
    nav { top: 6px; }
    section { margin-top: 42px; }
  }
`;

function SectionHead({ kicker, title, children }: { kicker: string; title: string; children?: React.ReactNode }) {
  return (
    <div className="section-head">
      <p className="kicker">{kicker}</p>
      <h2>{title}</h2>
      {children ? <div className="muted">{children}</div> : null}
    </div>
  );
}

export default function Artifact() {
  return (
    <>
      <style>{css}</style>
      <main className="page">
        <header className="hero">
          <p className="eyebrow">Mickey infrastructure · declared topology review</p>
          <h1>How every VM fits together—and where Ansible begins and ends</h1>
          <p className="lede">
            The short version: one Proxmox host runs nine Terraform-managed Linux guests plus one manually imported Windows 7 guest. The <code>mickey-infra</code> VM is the shared-services and storage hub; Terraform builds machines, Ansible configures operating systems, and a separate runtime repo deploys Traefik, Consul, and observability.
          </p>
          <div className="pills">
            <span className="pill">1 Proxmox node</span>
            <span className="pill">9 Terraform guests</span>
            <span className="pill">1 manual Windows guest</span>
            <span className="pill">5 generated role groups</span>
            <span className="pill">10.25.1.0/24 LAN</span>
          </div>
          <div className="notice">
            <strong>Scope:</strong> this explains the desired state in the current <code>mickey-platform</code> and <code>mickey-infra</code> checkouts. It is not a fresh hypervisor status poll. The generated inventory records the website VM’s most recently resolved DHCP address as <code>10.25.1.143</code>, but DHCP can change.
          </div>
        </header>

        <nav aria-label="Explainer sections">
          <a href="#mental-model">Mental model</a>
          <a href="#topology">VM topology</a>
          <a href="#catalog">All VMs</a>
          <a href="#roles">Role details</a>
          <a href="#services">Shared services</a>
          <a href="#ansible">How Ansible works</a>
          <a href="#operations">Operator flow</a>
          <a href="#caveats">Caveats</a>
          <a href="#sources">Sources</a>
        </nav>

        <section id="mental-model">
          <SectionHead kicker="01 · Mental model" title="Three automation layers, one deliberate manual exception">
            <p>The easiest way to understand the system is by responsibility, not by filename.</p>
          </SectionHead>
          <div className="grid">
            <article className="card accent">
              <h3>Terraform: machine construction</h3>
              <p>Terraform talks to Proxmox. It clones cloud-init templates, assigns VMIDs, CPU, memory, disks, NICs, startup policy, and cloud-init network/user settings. It also writes the generated Ansible guest inventory after it knows each target IP.</p>
            </article>
            <article className="card accent">
              <h3>Ansible: host and operating-system configuration</h3>
              <p>Ansible connects over SSH, applies the Proxmox host baseline, installs common guest packages and admin tooling, and then adds role-specific behavior such as Samba/NFS, Docker, Consul clients, Yocto tooling, project sync, or website development dependencies.</p>
            </article>
            <article className="card">
              <h3><code>mickey-infra</code> repo: runtime services</h3>
              <p>The platform repo prepares the infra VM; it intentionally does not own the full application runtime. The sibling runtime repo deploys Traefik, the Consul server, Grafana, Prometheus, Loki, Alloy, exporters, and infra-owned Consul registrations.</p>
            </article>
            <article className="card warn">
              <h3>Manual exception: <code>mickey-ise7</code></h3>
              <p>The preserved Windows 7/Xilinx environment is imported from a VMware VMDK chain. It is not a normal cloud-init clone, is excluded from the generated inventory, and does not receive the Linux Ansible baseline.</p>
            </article>
          </div>
        </section>

        <section id="topology">
          <SectionHead kicker="02 · Deployment view" title="One hypervisor, grouped guests, and two distinct storage tiers">
            <p>The diagram emphasizes placement and storage. Every VM NIC is attached to Proxmox bridge <code>vmbr0</code>; the static guests live on <code>10.25.1.0/24</code>, while the website VM uses DHCP plus QEMU guest-agent discovery.</p>
          </SectionHead>
          <div className="diagram-shell">
            <DiagramBlock
              title="Mickey VM deployment and storage layout"
              tool="d2"
              source="./vm-deployment.d2"
              output="./vm-deployment.svg"
              command="d2 vm-deployment.d2 vm-deployment.svg"
            />
          </div>
          <div className="stats">
            <div className="stat"><strong>700–710</strong><span>VMID range in use, with intentional gaps</span></div>
            <div className="stat"><strong>4</strong><span>Ubuntu template generations: 18, 22, 24, 26</span></div>
            <div className="stat"><strong>2</strong><span>Main Proxmox datastores: local-lvm and bulk</span></div>
            <div className="stat"><strong>1</strong><span>Shared-services hub: mickey-infra</span></div>
          </div>
        </section>

        <section id="catalog">
          <SectionHead kicker="03 · Complete catalog" title="Every VM declared or documented here">
            <p><strong>Started</strong> means Terraform’s desired state immediately after apply; <strong>on boot</strong> means Proxmox should start it automatically when the hypervisor boots. Those are separate controls.</p>
          </SectionHead>
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>VM / VMID</th><th>Role and OS</th><th>Address</th><th>Compute</th><th>Disk placement</th><th>Power policy</th><th>Automation membership</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td><strong>mickey-infra</strong><br /><code>700</code></td>
                  <td>Infra hub<br />Ubuntu 24.04</td>
                  <td><code>10.25.1.206/24</code></td>
                  <td>4 vCPU<br />16 GiB RAM</td>
                  <td>220 GB OS on <code>local-lvm</code><br />2,048 GB <code>scsi1</code> declared on <code>bulk</code>; docs also describe manual share-disk cutover and separate fast NVMe passthrough</td>
                  <td>started: yes<br />on boot: yes</td>
                  <td><span className="tag">infra_vms</span><span className="tag">guest_vms</span></td>
                </tr>
                <tr>
                  <td><strong>mickey-erp</strong><br /><code>701</code></td>
                  <td>ERP/application slot<br />Ubuntu 24.04</td>
                  <td><code>10.25.1.208/24</code></td>
                  <td>6 vCPU<br />24 GiB max / 8 GiB balloon floor</td>
                  <td>160 GB OS on <code>local-lvm</code></td>
                  <td>started: yes<br />on boot: no</td>
                  <td><span className="tag">erp_vms</span><span className="tag">consul_client_vms</span></td>
                </tr>
                <tr>
                  <td><strong>mickey-thud</strong><br /><code>702</code></td>
                  <td>Legacy Yocto build<br />Ubuntu 18.04</td>
                  <td><code>10.25.1.199/24</code></td>
                  <td>4 vCPU<br />16 GiB RAM</td>
                  <td>400 GB OS/build disk on <code>bulk</code>, I/O thread enabled</td>
                  <td>started: no<br />on boot: no</td>
                  <td><span className="tag">build_vms</span><span className="tag">consul_client_vms</span><br />USB IDs <code>14b0:0206</code> and <code>1a86:7523</code></td>
                </tr>
                <tr>
                  <td><strong>mickey-ise7</strong><br /><code>703</code></td>
                  <td>Legacy Xilinx ISE 14.7<br />Windows 7</td>
                  <td>Not declared in normal inventory</td>
                  <td>4 vCPU<br />8 GiB RAM</td>
                  <td>Imported 100 GiB legacy disk on <code>bulk</code>; SeaBIOS, i440fx, LSI SCSI, e1000 NIC</td>
                  <td>importer can start it<br />on boot: no</td>
                  <td><span className="tag manual">manual import</span><span className="tag manual">no normal Ansible</span></td>
                </tr>
                <tr>
                  <td><strong>mickey-scarthgap</strong><br /><code>704</code></td>
                  <td>Modern Yocto/Protech build<br />Ubuntu 22.04</td>
                  <td><code>10.25.1.210/24</code></td>
                  <td>4 vCPU<br />20 GiB max / 8 GiB balloon floor</td>
                  <td>500 GB OS/build disk on <code>bulk</code>; dedicated local Yocto volume mounted by UUID at <code>/mnt/yocto-local</code></td>
                  <td>started: yes<br />on boot: no</td>
                  <td><span className="tag">build_vms</span><span className="tag">consul_client_vms</span></td>
                </tr>
                <tr>
                  <td><strong>mickey-at4</strong><br /><code>706</code></td>
                  <td>Utility guest<br />Ubuntu 26.04</td>
                  <td><code>10.25.1.211/24</code></td>
                  <td>2 vCPU<br />8 GiB max / 2 GiB balloon floor</td>
                  <td>50 GB OS on <code>local-lvm</code></td>
                  <td>started: yes<br />on boot: no</td>
                  <td><span className="tag">utility_vms</span><span className="tag">no Consul client</span></td>
                </tr>
                <tr>
                  <td><strong>mickey-tmp</strong><br /><code>707</code></td>
                  <td>Larger scratch/utility guest<br />Ubuntu 26.04</td>
                  <td><code>10.25.1.212/24</code></td>
                  <td>6 vCPU<br />16 GiB max / 2 GiB balloon floor</td>
                  <td>50 GB OS on <code>local-lvm</code></td>
                  <td>started: yes<br />on boot: no</td>
                  <td><span className="tag">utility_vms</span><span className="tag">no Consul client</span></td>
                </tr>
                <tr>
                  <td><strong>mickey-controller</strong><br /><code>708</code></td>
                  <td>Fleet/controller utility<br />Ubuntu 26.04</td>
                  <td><code>10.25.1.214/24</code></td>
                  <td>2 vCPU<br />8 GiB max / 2 GiB balloon floor</td>
                  <td>50 GB OS on <code>local-lvm</code></td>
                  <td>started: yes<br />on boot: yes</td>
                  <td><span className="tag">utility_vms</span><span className="tag">fleet update timers</span></td>
                </tr>
                <tr>
                  <td><strong>mickey-brimstone</strong><br /><code>709</code></td>
                  <td>Brimstone/Protech build<br />Ubuntu 22.04</td>
                  <td><code>10.25.1.190/24</code></td>
                  <td>4 vCPU<br />20 GiB max / 8 GiB balloon floor</td>
                  <td>500 GB OS/build disk on <code>bulk</code>, I/O thread enabled</td>
                  <td>started: yes<br />on boot: no</td>
                  <td><span className="tag">build_vms</span><span className="tag">consul_client_vms</span></td>
                </tr>
                <tr>
                  <td><strong>mickey-galvanic-website</strong><br /><code>710</code></td>
                  <td>Website development<br />Ubuntu 26.04</td>
                  <td>DHCP via <code>eth0</code><br />last generated: <code>10.25.1.143</code></td>
                  <td>4 vCPU<br />12 GiB max / 8 GiB balloon floor</td>
                  <td>120 GB OS on <code>local-lvm</code></td>
                  <td>started: yes<br />on boot: yes</td>
                  <td><span className="tag">website_vms</span><span className="tag">consul_client_vms</span></td>
                </tr>
              </tbody>
            </table>
          </div>
          <p className="small muted" style={{ marginTop: 12 }}>VMID <code>705</code> is not assigned in the current configuration. The numeric gap has no automation meaning by itself.</p>
        </section>

        <section id="roles">
          <SectionHead kicker="04 · Role deep dive" title="What each class of VM is actually for" />
          <div className="grid">
            <article className="card accent">
              <h3>Infra: the shared-services boundary</h3>
              <p><code>mickey-infra</code> exists so file serving and platform services do not run directly on the hypervisor. Ansible prepares disks, mounts <code>/srv/share</code> and <code>/srv/mickey-shared-fast</code>, exposes local aliases under <code>/mnt</code>, configures Samba and NFS, enables Docker, and publishes the persistent-tools depot.</p>
              <p>The separate runtime repo then launches Traefik, Consul, and observability containers. This separation lets Proxmox maintenance remain distinct from service-stack changes.</p>
            </article>
            <article className="card">
              <h3>ERP: reserved application capacity</h3>
              <p><code>mickey-erp</code> is a deliberately roomy Ubuntu 24 guest for ERP workloads. It gets the common baseline, CIFS/NFS mounts, and a host-level Consul client, but the platform repo does not invent or deploy an ERP application. The future application repo should own its process and Consul service definition.</p>
            </article>
            <article className="card">
              <h3>Build fleet: explicit, capacity-aware workhorses</h3>
              <p>The three build guests all use large <code>bulk</code> disks so expensive Yocto trees do not consume the fast VM datastore. They receive build packages, SSH/repository wiring, share helpers, fetch diagnostics, and a Yocto throttling service. The architecture assumes heavy builds are scheduled intentionally rather than all consuming host capacity at once.</p>
              <ul>
                <li><strong>Thud</strong> preserves Ubuntu 18 and Node 16 compatibility and remains off unless needed.</li>
                <li><strong>Scarthgap</strong> is the modern Protech/Digi Embedded Yocto slot, uses Node 24, enables periodic build throttling, and puts BitBake <code>TMPDIR</code> on <code>/mnt/yocto-local</code>.</li>
                <li><strong>Brimstone</strong> shares the Ubuntu 22 baseline but intentionally syncs only <code>brimestone</code> and <code>Protech</code>.</li>
              </ul>
            </article>
            <article className="card">
              <h3>Utility fleet: disposable specialization with a common baseline</h3>
              <p><code>mickey-at4</code>, <code>mickey-tmp</code>, and <code>mickey-controller</code> all receive Ubuntu 26, the shared mounts, Node 24 tooling, admin dotfiles, Codex/Claude integration, and optional project synchronization. They intentionally do not belong to <code>consul_client_vms</code>.</p>
              <p><code>mickey-controller</code> is the only utility VM marked for Proxmox autostart and is the designated host for Codex and Claude fleet-update timers.</p>
            </article>
            <article className="card">
              <h3>Website development: dynamic address, service-aware guest</h3>
              <p>The website VM is the only DHCP guest. Terraform forces it to start during initial provisioning, installs QEMU guest-agent vendor data, waits for the selected <code>eth0</code> address, and refuses the topology if exactly one useful IPv4 cannot be resolved. Ansible installs Docker, mounts the shares, configures GitHub credentials, and clones the website repo once. Its role vars disable the normal Chrome install and enable the Lavish client from persistent tools.</p>
            </article>
            <article className="card warn">
              <h3>Windows ISE: deliberately outside the normal model</h3>
              <p>The import flow resolves the active VMware snapshot chain, converts it locally to one qcow2, uploads it through the Proxmox API, and creates VMID 703 with legacy-compatible virtual hardware. Windows-side Xilinx/Digilent setup, RDP enablement, and cable validation remain manual. Rebuilding an existing VM is also intentionally not automated.</p>
            </article>
          </div>
        </section>

        <section id="services">
          <SectionHead kicker="05 · Data and service flow" title="Why mickey-infra is the hub without becoming the hypervisor">
            <p>Three separate sharing concepts are easy to conflate: the ordinary Samba share, the fast NFS workspace, and the read-only persistent tool depot.</p>
          </SectionHead>
          <div className="diagram-shell">
            <DiagramBlock
              title="Shared storage, discovery, and routing relationships"
              tool="d2"
              source="./shared-services.d2"
              output="./shared-services.svg"
              command="d2 shared-services.d2 shared-services.svg"
            />
          </div>
          <div className="grid" style={{ marginTop: 14 }}>
            <article className="card">
              <h3><code>mickey-share</code>: general shared data over SMB</h3>
              <p>The system of record is <code>/srv/share</code> on <code>mickey-infra</code>. The infra VM bind-mounts that locally as <code>/mnt/mickey-share</code>; other Linux guests and the Proxmox host mount the Samba export at the same path. Build guests also get explicit <code>mickey-share-mount</code> and <code>mickey-share-umount</code> helpers so operators can treat it as an artifact exchange boundary.</p>
            </article>
            <article className="card">
              <h3><code>mickey-shared-fast</code>: fast cross-host working data</h3>
              <p>The infra VM mounts the fast device at <code>/srv/mickey-shared-fast</code>, exposes <code>/mnt/mickey-shared-fast</code> locally, and exports it over NFSv4.2 to the LAN. It carries shared Codex/Claude state, global and host-private skills, and host-specific pnpm stores. The NFS export uses <code>root_squash</code> and maps anonymous access to UID/GID 1000.</p>
            </article>
            <article className="card">
              <h3><code>persistent-tools</code>: centrally built, read-only clients</h3>
              <p>The infra VM owns <code>/srv/persistent-tools</code>, builds pinned shared tools such as Galvanic UI and Lavish there, and exports it read-only over NFS. Clients mount it at <code>/mnt/persistent-tools</code>. This gives every managed guest the same built artifacts without making each guest a separate build authority.</p>
            </article>
            <article className="card">
              <h3>Consul + Traefik: decentralized application registration</h3>
              <p>The Consul server and Traefik live in Docker on <code>mickey-infra</code>. ERP, website, and build VMs run host-level Consul clients installed by Ansible. Application repos own the files they place under <code>/etc/consul.d</code>; Traefik reads the resulting Consul Catalog. Infra-owned public endpoints stay in the runtime repo. The current runtime path is plain HTTP, not TLS/ACME.</p>
            </article>
          </div>
        </section>

        <section id="ansible">
          <SectionHead kicker="06 · Ansible mechanics" title="From Terraform output to repeatable role-specific configuration">
            <p>Ansible is not discovering the fleet independently. It consumes one tracked host inventory and one Terraform-generated guest inventory, then composes variables and tasks from group membership.</p>
          </SectionHead>
          <div className="diagram-shell">
            <DiagramBlock
              title="Terraform-to-Ansible control flow"
              tool="d2"
              source="./ansible-flow.d2"
              output="./ansible-flow.svg"
              command="d2 ansible-flow.d2 ansible-flow.svg"
            />
          </div>

          <div className="boundary" style={{ marginTop: 18 }}>
            <h3>1. Inventory</h3>
            <div>
              <p><code>ansible/inventory/hosts.yml</code> is small and tracked: it contains only <code>mickey-pve</code> at <code>10.25.1.207</code>, using root SSH.</p>
              <p><code>ansible/inventory/hosts.generated.yml</code> is written by Terraform and ignored by Git. It contains all nine Linux guests, SSH metadata, role metadata, and groups such as <code>build_vms</code>, <code>utility_vms</code>, and <code>consul_client_vms</code>. Guest playbooks receive both inventory files; the host-only playbook receives only the static one.</p>
            </div>
          </div>
          <div className="boundary">
            <h3>2. Group membership</h3>
            <div>
              <p>Terraform derives role groups from each VM’s <code>role</code> field. The separate boolean <code>consul_client</code> creates an orthogonal membership: a build VM is both <code>build_vms</code> and <code>consul_client_vms</code>. That is why the shared admin layer can say “install Consul if this host belongs to the Consul group” without duplicating the decision in every playbook.</p>
            </div>
          </div>
          <div className="boundary">
            <h3>3. Variables</h3>
            <div>
              <p><code>group_vars/all.yml</code> establishes the common contract: admin user, mount paths, package baseline, tool pins, Codex/Claude locations, GitHub auth settings, dotfiles, NFS options, and feature switches. Role files add packages and specialized paths. Playbook-local vars set host-specific differences such as Node 16 on Thud versus Node 24 elsewhere.</p>
              <p>The checkout mirrors these group-variable files under both <code>ansible/group_vars</code> and <code>ansible/inventory/group_vars</code>; the inventory-adjacent copy is available when the inventories are loaded.</p>
            </div>
          </div>
          <div className="boundary">
            <h3>4. Secrets</h3>
            <div>
              <p><code>scripts/run-ansible.sh</code> requires both <code>ansible-playbook</code> and <code>sops</code>. It decrypts <code>secrets/prod.sops.yaml</code> into a temporary file, registers a cleanup trap, passes the temp path as <code>secret_vars_file</code>, and lets each playbook include it. Secret-bearing copy/shell operations generally use <code>no_log: true</code>. Missing Samba credentials cause role playbooks that need the share to fail early.</p>
            </div>
          </div>
          <div className="boundary">
            <h3>5. Base layer</h3>
            <div>
              <p><code>bootstrap-vm-base.yml</code> disables continuous discard on the root filesystem, enables periodic trim when supported, installs the evaluated package list, pins Chrome, GitHub CLI, Herdr, and D2, configures the bootstrap admin user and authorized keys, and normalizes the hostname and local hosts entry.</p>
              <p>Build VMs select a raw-APT path because the legacy environment cannot always rely on a modern Python interpreter at the beginning of the run. Thud additionally bootstraps a newer standalone Python specifically for Ansible compatibility.</p>
            </div>
          </div>
          <div className="boundary">
            <h3>6. Role layer</h3>
            <div>
              <p>Each playbook then adds only its role’s responsibilities: infra disk/export setup; ERP share mounts; utility project sync; website Docker and repo clone; or build packages, SSH bundles, repositories, diagnostics, throttling, and device tooling. The Proxmox host playbook is separate because it manages repositories and physical storage, including the guarded <code>/dev/sda</code> bulk-datastore initialization.</p>
            </div>
          </div>
          <div className="boundary">
            <h3>7. Admin tooling</h3>
            <div>
              <p><code>configure-vm-admin-tooling.yml</code> is the post-mount composition point. It conditionally installs the Consul client, then Codex and Claude, shared auth wiring, managed guidance, dotfiles, GitHub Packages credentials, and the persistent-tools client. Doing this after mounts exist matters because Codex/Claude state and pnpm stores deliberately point into shared storage.</p>
            </div>
          </div>
          <div className="boundary">
            <h3>8. Repeatability</h3>
            <div>
              <p>The playbooks are designed to be rerun: normal Ansible modules express desired state, while raw shell blocks explicitly check current versions, mounts, files, or service state and emit <code>changed</code> only when appropriate. “Repeatable” does not mean risk-free: storage initialization, VM import, repository cleanup, and external downloads have stronger preconditions and explicit guards.</p>
            </div>
          </div>
        </section>

        <section id="operations">
          <SectionHead kicker="07 · Operator workflow" title="The intended order of operations and why the order matters" />
          <ol className="flow-list">
            <li><strong>Build the required Proxmox cloud templates.</strong> Ubuntu 24 is the default server template; separate targets create Ubuntu 18, 22, and 26 templates. Terraform validates that exactly one matching template exists for every requested template name.</li>
            <li><strong>Prepare encrypted inputs.</strong> Non-secret topology lives in <code>envs/prod/terraform.tfvars</code>; the Proxmox token, SSH keys, guest password hash, Samba password, and package credentials come from the SOPS file.</li>
            <li><strong>Initialize, plan, and apply Terraform.</strong> The apply constructs the nine Linux VMs, waits for the DHCP guest’s agent-reported address, and writes <code>hosts.generated.yml</code>.</li>
            <li><strong>Configure the Proxmox host baseline.</strong> This sets no-subscription repositories, validates the exact 4 TB Seagate disk model, creates the <code>bulk</code> datastore only with an explicit wipe confirmation, and prepares SMB/NFS client mounts. This step is intentionally guarded because it crosses a physical-storage boundary.</li>
            <li><strong>Attach/cut over data disks before configuring infra.</strong> The docs require the existing Samba data disk to be moved from <code>mickey-main</code> to <code>mickey-infra</code>. Fast-shared storage is also identified and mounted by the infra playbook. Disk identity must be correct before Ansible formats or exports anything.</li>
            <li><strong>Run <code>make ansible-infra</code>.</strong> This establishes the shared storage and tooling foundation on which the other guests depend.</li>
            <li><strong>Run the relevant guest role playbooks.</strong> ERP, utility, website, and each build guest have explicit Make targets. Build playbooks are intentionally omitted from the aggregate <code>site.yml</code> because build capacity and legacy compatibility are operated deliberately.</li>
            <li><strong>Deploy the runtime stack from <code>mickey-infra</code>.</strong> Its own bootstrap/deploy scripts start the core and observability containers after the platform layer is ready.</li>
            <li><strong>Import Windows 7 separately if needed.</strong> Dry-run chain resolution first, then perform the conversion/upload/import. Finish the Windows-only driver and Xilinx steps inside the guest.</li>
          </ol>

          <CodeBlock
            title="Primary operator commands"
            filename="mickey-platform/Makefile targets"
            language="bash"
            code={commands}
            lineNumbers={false}
            wrap={true}
          />
        </section>

        <section id="caveats">
          <SectionHead kicker="08 · Important caveats" title="Things the diagrams intentionally do not smooth over" />
          <div className="grid">
            <article className="card warn">
              <h3>Declared state is not live state</h3>
              <p><code>started = true</code> is a Terraform desire, not proof that a VM is running now. Likewise, the generated DHCP address is the last address Terraform wrote after a successful resolution. A live status answer would require a separate read-only Proxmox/guest check.</p>
            </article>
            <article className="card warn">
              <h3>Infra disks cross automation boundaries</h3>
              <p>The current tfvars declare a 2,048 GB <code>scsi1</code> disk for infra, while the architecture notes also require manual reattachment of an existing 2 TiB Samba data disk and describe separate Kingston NVMe passthrough for the fast share. The safe interpretation is that identity and cutover of these data devices remain operator-controlled, even though the desired attachment/mount shape is documented in code.</p>
            </article>
            <article className="card">
              <h3>Build VMs are not an always-on cluster</h3>
              <p>Scarthgap and Brimstone are currently desired “started” after apply, but none of the three build VMs is configured to autostart with Proxmox. The docs explicitly say heavy builds should be capacity-planned and that Thud/Scarthgap are not meant to run heavy work simultaneously.</p>
            </article>
            <article className="card">
              <h3>Service ownership is decentralized</h3>
              <p>Ansible installs Consul clients; it does not own every application registration. The runtime repo owns infra endpoints, while application repos own their service definitions. This avoids a central config edit for every app but means troubleshooting must consider both the host agent and the application repo.</p>
            </article>
            <article className="card">
              <h3>The current edge is plain HTTP</h3>
              <p>The <code>mickey-infra</code> README says active deployment is HTTP-only, with no TLS, ACME, or reverse-proxy authentication. That is an explicit current constraint, not something hidden by the topology diagram.</p>
            </article>
            <article className="card">
              <h3>Host-key checking is disabled</h3>
              <p><code>ansible.cfg</code> sets <code>host_key_checking = False</code> and uses <code>IdentitiesOnly=yes</code>. This makes rebuilds and a private-lab workflow smoother, but it weakens SSH host-identity verification and should be understood as part of the current trust model.</p>
            </article>
          </div>
        </section>

        <section id="sources">
          <SectionHead kicker="09 · Evidence map" title="The files that define this explanation">
            <p>These are local repository sources, not external documentation or inferred live state.</p>
          </SectionHead>
          <div className="source-list">
            <div className="source"><code>envs/prod/terraform.tfvars</code><span className="muted">All nine Terraform VM definitions and shared network/storage defaults.</span></div>
            <div className="source"><code>terraform/main.tf</code><span className="muted">Proxmox VM resource, cloud-init behavior, QEMU agent checks, and inventory output.</span></div>
            <div className="source"><code>terraform/locals.tf</code><span className="muted">Default merging, role groups, Consul groups, DHCP IP selection, and inventory shape.</span></div>
            <div className="source"><code>ansible/inventory/hosts.generated.yml</code><span className="muted">Current generated guest groups and last resolved website DHCP address.</span></div>
            <div className="source"><code>Makefile</code><span className="muted">Operator entry points and which inventory/playbook each target invokes.</span></div>
            <div className="source"><code>scripts/run-ansible.sh</code><span className="muted">SOPS decryption, inventory composition, temporary secret file, and ansible-playbook launch.</span></div>
            <div className="source"><code>ansible/tasks/bootstrap-vm-base.yml</code><span className="muted">Common package, tool, user, hostname, discard, and trim baseline.</span></div>
            <div className="source"><code>ansible/tasks/configure-vm-admin-tooling.yml</code><span className="muted">Consul, Codex, Claude, auth, guidance, dotfiles, GitHub, and tools-depot composition.</span></div>
            <div className="source"><code>ansible/playbooks/*.yml</code><span className="muted">Per-role configuration for Proxmox, infra, ERP, utility, website, and build guests.</span></div>
            <div className="source"><code>docs/architecture.md</code><span className="muted">Design intent, role boundaries, storage model, and service-discovery split.</span></div>
            <div className="source"><code>docs/windows-7-ise.md</code><span className="muted">Manual Windows import shape and in-guest steps.</span></div>
            <div className="source"><code>../mickey-infra/README.md</code><span className="muted">Runtime-service ownership, storage paths, HTTP constraint, and deploy flow.</span></div>
          </div>
        </section>

        <footer className="footer">
          Generated as a Lavish review artifact from the current local checkout. Diagram sources are included beside the artifact and can be expanded from each diagram panel.
        </footer>
      </main>
    </>
  );
}
