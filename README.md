# Backup Script Documentation

## English Documentation

This backup script is designed to back up files or directories defined in a configuration file. The configuration file (typically named `files-backup.conf`) should specify the variable `FILES_TO_BACKUP` as a comma-separated list of paths. The script supports the following modes:
  
- **local**: The backup is stored in a local directory. Optionally, the backup can be transferred to a remote host via SSH if the `REMOTE_HOST` variable is provided.
- **s3**: The backup is uploaded to an AWS S3 bucket via the AWS CLI.
- **gcp**: The backup is uploaded to a Google Cloud Storage bucket using `gsutil`.

### Features

- **Compression & Encryption:**  
  The script creates backups using `tar` with gzip compression. If an encryption key (`ENCRYPTION_KEY`) is provided, the backup file will be encrypted using GPG with AES256 symmetric encryption.
  
- **Configuration:**  
  Default values are set within the script but can be overwritten via the configuration file. The `FILES_TO_BACKUP` variable should be defined as a comma-separated list (e.g., `FILES_TO_BACKUP="/etc,/var/www,/home/usuario"`).

- **Retention Policy:**  
  Backups older than a specified number of days (`RETENTION_DAYS`) are automatically deleted.

### How to Use

1. **Edit the Configuration File:**  
   Modify `files-backup.conf` to set variables such as `FILES_TO_BACKUP`, `LOCAL_PATH`, `CLOUD_BUCKET`, etc.

2. **Run the Script with Options:**  
   - `-m`: Mode of operation (`local`, `s3`, or `gcp`).
   - `-l`: Local backup path (or destination folder on the remote host when using `-h`).
   - `-b`: Cloud bucket path (for `s3` and `gcp` modes).
   - `-k`: Encryption key for GPG (AES256).
   - `-T`: Number of days for backup retention.
   - `-h`: Remote host (optional, for SSH transfers).

**Example Commands:**

- Backup locally with a retention of 7 days:  
  `./backup_script.sh -m local -l /backups/files -T 7`
  
- Backup to Google Cloud Storage with encryption:  
  `./backup_script.sh -m gcp -b gs://my-bucket/path -k mysecret`

### Decryption Command

To decrypt an encrypted backup file (with a `.gpg` extension) created using the script, you can use the following command:

`gpg --decrypt --batch --yes --passphrase <your_passphrase> -o output_file backup_file`

Replace `<your_passphrase>` with your encryption key, `backup_file` with the encrypted file name, and `output_file` with the name for the decrypted output.

## Documentación en Español

Este script de backup está diseñado para respaldar archivos o directorios definidos en un archivo de configuración. El archivo de configuración (usualmente llamado `files-backup.conf`) debe especificar la variable `FILES_TO_BACKUP` como una lista separada por comas de rutas. El script admite los siguientes modos:

- **local**: El respaldo se guarda en un directorio local. Opcionalmente, puede transferirse a un host remoto vía SSH si se proporciona la variable `REMOTE_HOST`.
- **s3**: El respaldo se carga en un bucket de AWS S3 utilizando AWS CLI.
- **gcp**: El respaldo se carga en un bucket de Google Cloud Storage mediante `gsutil`.

### Características

- **Compresión y Encriptación:**  
  El script crea backups usando `tar` con compresión gzip. Si se proporciona una clave de encriptación (`ENCRYPTION_KEY`), el archivo se encriptará usando GPG con encriptación simétrica AES256.
  
- **Configuración:**  
  El script tiene valores por defecto que pueden ser sobrescritos mediante el archivo de configuración. La variable `FILES_TO_BACKUP` debe definirse como una lista separada por comas (por ejemplo, `FILES_TO_BACKUP="/etc,/var/www,/home/usuario"`).

- **Política de Retención:**  
  Se eliminan automáticamente los backups que sean más antiguos que el número de días especificado en `RETENTION_DAYS`.

### Cómo Usarlo

1. **Editar el Archivo de Configuración:**  
   Modifica `files-backup.conf` para definir variables como `FILES_TO_BACKUP`, `LOCAL_PATH`, `CLOUD_BUCKET`, etc.

2. **Ejecutar el Script con las Opciones Adecuadas:**  
   - `-m`: Modo de operación (`local`, `s3` o `gcp`).
   - `-l`: Ruta donde se almacenará el backup (o carpeta destino en el host remoto al usar `-h`).
   - `-b`: Ruta del bucket en la nube (para los modos `s3` y `gcp`).
   - `-k`: Clave de encriptación para GPG (AES256).
   - `-T`: Número de días de retención del backup.
   - `-h`: Host remoto (opcional, para transferencias vía SSH).

**Ejemplos de Uso:**

- Realizar un backup local con retención de 7 días:  
  `./backup_script.sh -m local -l /backups/files -T 7`
  
- Realizar un backup a Google Cloud Storage con encriptación:  
  `./backup_script.sh -m gcp -b gs://mi-bucket/path -k miclave`

### Comando para Desencriptar

Para desencriptar un archivo de backup encriptado (con extensión `.gpg`) que fue creado utilizando el script, se puede utilizar el siguiente comando:

`gpg --decrypt --batch --yes --passphrase <tu_clave> -o archivo_salida archivo_backup`

Sustituye `<tu_clave>` por tu clave de encriptación, `archivo_backup` por el nombre del archivo encriptado y `archivo_salida` por el nombre del archivo desencriptado.
