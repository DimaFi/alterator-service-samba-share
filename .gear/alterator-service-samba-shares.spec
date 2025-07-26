%define _unpackaged_files_terminate_build 1
%define service service-samba-shares
Name: alterator-service-samba-shares
Version: 0.1
Release: alt1

Summary: Service for managment samba shares
License: GPLv3
Group: System/Configuration/Other
URL: https://gitlab.basealt.space/alt/alterator-service-samba-shares

BuildArch: noarch
Source: %name-%version.tar

BuildRequires(pre): rpm-macros-alterator

Requires: alterator-module-executor
Requires: alterator-interface-service
Requires: alterator-entry

%description
Service for management samba shares.

%prep
%setup

%install
mkdir -p %buildroot%_alterator_datadir/services
mkdir -p %buildroot%_localstatedir/alterator/service/%service/config-backup
mkdir -p %buildroot%_localstatedir/alterator/service/%service/backup

install -p -D -m755 src/%service %buildroot%_bindir/%service
install -p -D -m644 src/%service.backend %buildroot%_alterator_datadir/backends/%service.backend
install -p -D -m644 src/%service.service %buildroot%_alterator_datadir/service/%service.service

%files
%_alterator_datadir/backends/%service.backend
%_alterator_datadir/service/%service.service
%_bindir/%service

%changelog
* Tue Jul 26 2025 Dmitry Filippenko <dmitfilippenko@yandex.ru> 0.1-alt1
- Initial commit
