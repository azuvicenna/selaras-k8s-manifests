# Selaras SIMRS - Kubernetes Manifests

Repositori ini memuat seluruh berkas spesifikasi dan orkestrasi Kubernetes (**K8s Manifests**) untuk **Platform Sistem Informasi Manajemen Rumah Sakit (SIMRS) Selaras**.

Spesifikasi disusun dengan standar **Kustomize** (bawaan resmi `kubectl`), memungkinkan pengelolaan konfigurasi deklaratif tanpa *templating engine* rumit, siap diintegrasikan dengan alat GitOps seperti **ArgoCD** atau **FluxCD**.

---

## 🏛️ Arsitektur Direktori Manifest

```
selaras-k8s-manifest/
├── base/                              # Deklarasi dasar (Base layer)
│   ├── namespace/                     # Namespace 'selaras'
│   │   └── namespace.yaml
│   ├── configs/                       # Global ConfigMap & Secret
│   │   ├── configmap.yaml
│   │   ├── secret.yaml                # Default credentials untuk dev
│   │   └── secret.example.yaml        # Template credentials aman
│   ├── infrastructure/                # Layanan Data & Broker
│   │   ├── postgres/                  # PostgreSQL 18 Multi-Database (StatefulSet & PVC)
│   │   ├── redis/                     # Redis 7 Cache & Session (Deployment)
│   │   ├── minio/                     # Object Storage S3 (Deployment, PVC & Bucket Init Job)
│   │   ├── rabbitmq/                  # RabbitMQ 3 Message Broker (StatefulSet & PVC)
│   │   └── migrator/                  # Unified DB Migration Job
│   ├── services/                      # 12 Core Clinical & Admin Microservices
│   │   ├── auth-service/              # JWT & RBAC (:50057)
│   │   ├── patient-service/           # Demografi Pasien (:50051)
│   │   ├── emr-service/               # Rekam Medis & SOAP (:50052)
│   │   ├── master-service/            # ICD-10, Faskes, Wilayah (:50053)
│   │   ├── bed-service/               # Bangsal & Kamar Rawat Inap (:50054)
│   │   ├── admission-service/         # Pendaftaran & Antrean (:50055)
│   │   ├── practitioner-service/      # Dokter & Tenaga Medis (:50056)
│   │   ├── billing-service/           # Kasir, Tarif & Invoice (:50058)
│   │   ├── pharmacy-service/          # Resep, Obat & Stok (:50059)
│   │   ├── laboratory-service/        # LIS, LOINC & Hasil Lab (:50060)
│   │   ├── radiology-service/         # RIS & Pemeriksaan Radiologi (:50061)
│   │   └── document-service/          # 20 PDF Templates Typst (:50062)
│   ├── gateways/                      # Layer API Gateway & BFF (dengan HPA)
│   │   ├── bff-web/                   # Web Portal Gateway (:8080)
│   │   ├── bff-mobile/                # Mobile Apps Gateway (:8081)
│   │   └── b2b-gateway/               # Enterprise Asuransi & Partner (:8082)
│   ├── workers/                       # Asynchronous Event Consumers
│   │   ├── satusehat-worker/          # Kemenkes SATUSEHAT FHIR R4 (:8085)
│   │   ├── bpjs-worker/               # BPJS VClaim, Antrean, Aplicares (:8086)
│   │   └── notification-worker/       # WhatsApp & Email Dispatcher (:8087)
│   ├── ingress/                       # NGINX Ingress Controller routing
│   │   └── ingress.yaml
│   ├── monitoring/                    # Observability Prometheus & Grafana
│   │   ├── prometheus/                # RBAC, ConfigMap, Deployment & Scrape Config
│   │   └── grafana/                   # Dashboard Visualization
│   └── kustomization.yaml             # Manifest Base Aggregator
├── overlays/                          # Environment Specific Overlays
│   ├── development/                   # 1 replica, resource ringan
│   ├── staging/                       # Lingkungan staging & test domain
│   └── production/                    # Multi-replica HA, TLS cert-manager, auto-scaling
├── scripts/                           # Skrip Deploy & Destroy otomatis
│   ├── deploy.ps1                     # PowerShell deploy script
│   ├── deploy.sh                      # Bash deploy script
│   ├── destroy.ps1                    # PowerShell cleanup script
│   └── destroy.sh                     # Bash cleanup script
├── .gitignore
└── README.md
```

---

## 📋 Prasyarat Lingkungan (Prerequisites)

Sebelum menjalankan cluster, pastikan alat-alat berikut telah terinstal pada mesin Anda:

1. **`kubectl`**: Versi `v1.24+` (Dilengkapi dukungan bawaan Kustomize `kubectl apply -k`).
   ```bash
   kubectl version --client
   ```
2. **Kubernetes Cluster**:
   - **Docker Desktop** (Paling mudah di Windows): Buka *Settings* $\rightarrow$ *Kubernetes* $\rightarrow$ Centang *Enable Kubernetes* $\rightarrow$ *Apply & Restart*.
   - **Minikube**:
     ```bash
     minikube start --cpus=4 --memory=8192 --disk-size=40g
     ```
   - **Kind** (*Kubernetes in Docker*):
     ```bash
     kind create cluster --name selaras
     ```
   - **Cloud Managed Kubernetes**: AWS EKS, Google GKE, atau Azure AKS.

---

## 🛠️ Langkah Demi Langkah Menjalankan Cluster (Step-by-Step Guide)

### Langkah 1: Persiapan Container Images

Jika Anda mendeploy ke cluster lokal (Docker Desktop, Minikube, atau Kind) menggunakan image hasil build lokal dari repositori `selaras-services`:

1. **Build seluruh Docker images**:
   Masuk ke repositori `selaras-services`:
   ```bash
   cd ../selaras-services
   docker compose --profile apps build
   ```

2. **Load Images ke Cluster Lokal (Khusus Minikube / Kind)**:
   * **Jika menggunakan Docker Desktop**: Langkah ini **tidak diperlukan**, karena Kubernetes Docker Desktop langsung berbagi image cache lokal dengan engine Docker host!
   * **Jika menggunakan Minikube**:
     ```bash
     minikube image load azuvicenna/selaras-bff-web:latest
     minikube image load azuvicenna/selaras-emr-service:latest
     # Dan seterusnya untuk image lainnya
     ```
   * **Jika menggunakan Kind**:
     ```bash
     kind load docker-image azuvicenna/selaras-bff-web:latest --name selaras
     ```

---

### Langkah 2: Konfigurasi Secrets & Environment

1. Masuk ke direktori `selaras-k8s-manifest`:
   ```bash
   cd selaras-k8s-manifest
   ```

2. Berkas `base/configs/secret.yaml` sudah disiapkan dengan kredensial bawaan (*default*) untuk kebutuhan pengujian lokal.
3. Untuk deployment **Staging** atau **Production**, salin dari template aman:
   ```bash
   cp base/configs/secret.example.yaml base/configs/secret.yaml
   ```
   Lalu sesuaikan password PostgreSQL, kredensial MinIO, RabbitMQ, BPJS, dan SATUSEHAT.

---

### Langkah 3: Eksekusi Deployment Menggunakan Kustomize

Pilih lingkungan (*environment*) target yang ingin dijalankan:

#### A. Lingkungan Development (Rekomendasi untuk Uji Coba Lokal)
```bash
# Opsi 1: Menggunakan skrip PowerShell (Windows)
.\scripts\deploy.ps1 -Environment development

# Opsi 2: Menggunakan skrip Bash (Linux / macOS / WSL)
./scripts/deploy.sh development

# Opsi 3: Menggunakan kubectl langsung
kubectl apply -k overlays/development
```

#### B. Lingkungan Production (High Availability & Multi-Replika)
```bash
# Menggunakan PowerShell (Windows)
.\scripts\deploy.ps1 -Environment production

# Atau via kubectl langsung
kubectl apply -k overlays/production
```

---

### Langkah 4: Memantau dan Memverifikasi Status Deployment

Setelah perintah deploy dijalankan, pantau kesiapan seluruh pod:

1. **Cek status semua pod**:
   ```bash
   # Untuk namespace default (production/staging)
   kubectl get pods -n selaras -o wide

   # Untuk namespace development
   kubectl get pods -n selaras-dev -o wide
   ```
   Tunggu hingga semua pod berstatus `Running` atau `Completed` (untuk Job).

2. **Cek eksekusi Migrasi Database**:
   ```bash
   kubectl logs -f job/selaras-migration-runner -n selaras
   ```
   *Output yang diharapkan:* Migrasi seluruh 12 database berhasil (`All migrations completed successfully`).

3. **Cek inisialisasi Bucket MinIO**:
   ```bash
   kubectl logs job/minio-init-buckets -n selaras
   ```
   *Output yang diharapkan:* Bucket `patient-documents`, `emr-documents`, dan `medical-documents` terbuat.

4. **Cek Persistent Volume Claims (PVC)**:
   ```bash
   kubectl get pvc -n selaras
   ```
   *Output yang diharapkan:* Status `Bound` untuk PostgreSQL (50Gi), MinIO (100Gi), dan RabbitMQ (20Gi).

5. **Cek Horizontal Pod Autoscaler (HPA)**:
   ```bash
   kubectl get hpa -n selaras
   ```

---

### Langkah 5: Mengakses Layanan (Port-Forwarding & Browser)

Jika Anda belum mengaktifkan NGINX Ingress Controller di cluster lokal, Anda dapat mengakses dashboard dan API gateway secara instan menggunakan `kubectl port-forward`:

#### 1. Portal Web & API Gateway (bff-web)
```bash
kubectl port-forward svc/bff-web 8080:8080 -n selaras
```
* Buka browser: `http://localhost:8080/healthz`
* Swagger UI / API Docs: `http://localhost:8080/docs/index.html`

#### 2. MinIO Object Storage Console
```bash
kubectl port-forward svc/minio 9001:9001 -n selaras
```
* Buka browser: `http://localhost:9001`
* User: `minioadmin` | Password: `minioadmin-secure-password`

#### 3. RabbitMQ Management Dashboard
```bash
kubectl port-forward svc/rabbitmq 15672:15672 -n selaras
```
* Buka browser: `http://localhost:15672`
* User: `selaras` | Password: `selaras123`

#### 4. Grafana Visualisasi SIMRS
```bash
kubectl port-forward svc/grafana 3000:3000 -n selaras
```
* Buka browser: `http://localhost:3000`
* User: `admin` | Password: `selaras`

#### 5. Prometheus Metrics Explorer
```bash
kubectl port-forward svc/prometheus 9090:9090 -n selaras
```
* Buka browser: `http://localhost:9090/targets` (Pastikan seluruh 18 targets berstatus `UP`).

---

### Langkah 6: Menjalankan End-to-End (E2E) Test terhadap Cluster K8s

Setelah port-forwarding aktif pada `bff-web` (`http://localhost:8080`), Anda dapat menguji seluruh integrasi 11 tahap *patient journey* langsung terhadap cluster Kubernetes:

Masuk ke folder `selaras-services`:
```powershell
cd ../selaras-services

# Jalankan pengujian E2E otomatis:
.\scripts\run-e2e.ps1

# Atau via Go test:
go test -v ./tests/e2e -run TestPatientJourneyE2E
```

Alur pengujian akan memverifikasi keterhubungan nyata antar pod:
Auth $\rightarrow$ Master $\rightarrow$ Patient $\rightarrow$ Admission $\rightarrow$ EMR/SOAP $\rightarrow$ Lab $\rightarrow$ Radiologi $\rightarrow$ Farmasi $\rightarrow$ Billing $\rightarrow$ Document Typst PDF $\rightarrow$ Composite Summary.

---

## 🌐 Mengakses via Ingress Controller (Domain Name)

Jika cluster Anda memiliki Ingress Controller (seperti Ingress-NGINX):

1. **Tambahkan pemetaan domain ke file `hosts` komputer Anda**:
   * Windows: `C:\Windows\System32\drivers\etc\hosts`
   * Linux / macOS: `/etc/hosts`
   ```text
   127.0.0.1 api.selaras.hospital.id
   127.0.0.1 mobile-api.selaras.hospital.id
   127.0.0.1 b2b.selaras.hospital.id
   127.0.0.1 storage.selaras.hospital.id
   127.0.0.1 minio-console.selaras.hospital.id
   127.0.0.1 rabbitmq.selaras.hospital.id
   127.0.0.1 grafana.selaras.hospital.id
   ```

2. Akses langsung melalui domain resmi:
   * Web Portal: `http://api.selaras.hospital.id`
   * MinIO: `http://minio-console.selaras.hospital.id`
   * RabbitMQ: `http://rabbitmq.selaras.hospital.id`
   * Grafana: `http://grafana.selaras.hospital.id`

---

## 🔧 Pemecahan Masalah Umum (Troubleshooting)

### 1. Pod Berstatus `ImagePullBackOff` atau `ErrImagePull`
* **Penyebab**: Image belum ada di registry publik atau cluster lokal belum memiliki image tersebut.
* **Solusi**:
  1. Pastikan image sudah dibuild: `docker compose --profile apps build`
  2. Jika menggunakan Minikube/Kind, muat image ke cluster:
     `minikube image load <image-name>` atau `kind load docker-image <image-name> --name selaras`
  3. Ubah `imagePullPolicy` di manifest menjadi `IfNotPresent` atau `Never`.

### 2. Pod `selaras-migration-runner` Berstatus `CrashLoopBackOff`
* **Penyebab**: Database PostgreSQL belum selesai menginisialisasi ke-12 database saat migrator berjalan.
* **Solusi**:
  1. Periksa log postgres: `kubectl logs statefulset/postgres -n selaras`
  2. Hapus job lama agar Kubernetes mengulang migrasi:
     ```bash
     kubectl delete job selaras-migration-runner -n selaras
     kubectl apply -f base/infrastructure/migrator/migration-job.yaml -n selaras
     ```

### 3. PVC Berstatus `Pending`
* **Penyebab**: Cluster belum memiliki *Default StorageClass* untuk *dynamic provisioning*.
* **Solusi**:
  Cek ketersediaan storage class:
  ```bash
  kubectl get sc
  ```
  Di Minikube, aktifkan default storage: `minikube addons enable storage-provisioner`.
  Di Docker Desktop, storage class `hostpath` otomatis tersedia.

---

## 🧹 Menghapus / Membersihkan Deployment (Teardown)

Untuk menghapus seluruh resource yang telah dibuat:

```bash
# Menggunakan PowerShell (Windows):
.\scripts\destroy.ps1 -Environment development

# Atau menggunakan Bash (Linux / macOS):
./scripts/destroy.sh development

# Atau via kubectl langsung:
kubectl delete -k overlays/development
```
Jika ingin menghapus volume data persisten (PVC):
```bash
kubectl delete pvc --all -n selaras
```
