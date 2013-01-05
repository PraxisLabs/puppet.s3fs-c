# iteego/puppet.s3fs: puppet recipes for use with the s3fs sofware
#                     in debian-based systems.
#
# Copyright 2012 Iteego, Inc.
# Author: Marcus Pemer <marcus@iteego.com>
#
# This file is part of iteego/puppet.s3fs.
#
# iteego/puppet.s3fs is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# iteego/puppet.s3fs is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with iteego/puppet.s3fs.  If not, see <http://www.gnu.org/licenses/>.
#

class s3fs-c {

  define line( $file, $line, $ensure = 'present' ) {
    case $ensure {
      default: {
        err ( "unknown ensure value ${ensure}" )
      }
      present: {
        exec { "/bin/echo '${line}' >> '${file}'":
          unless => "/bin/grep -qFx '${line}' '${file}'",
        }
      }
      absent: {
        exec { "/bin/grep -vFx '${line}' '${file}' | /usr/bin/tee '${file}' > /dev/null 2>&1":
          onlyif => "/bin/grep -qFx '${line}' '${file}'",
        }
      }
    }
  }

  define s3fs_installation
  {
    package {
      'pkg-config':
        ensure => present,
        require => Exec['aptgetupdate'];
      'build-essential':
        ensure => present,
        require => Exec['aptgetupdate'];
      'fuse-utils':
        ensure => present,
        require => Exec['aptgetupdate'];
      'mime-support':
        ensure => present,
        require => Exec['aptgetupdate'];
      'libfuse-dev':
        ensure => present,
        require => Exec['aptgetupdate'];
      'libcurl4-openssl-dev':
        ensure => present,
        require => Exec['aptgetupdate'];
      'libxml2-dev':
        ensure => present,
        require => Exec['aptgetupdate'];
      'libcrypto++-dev':
        ensure => present,
        require => Exec['aptgetupdate'];
    }

    file { 'aws-creds-file':
      path => '/etc/passwd-s3fs',
      mode => '600',
    }

    file { '/mnt/s3':
      ensure => directory,
    }

    file { 's3fs-cache-directory':
      path => '/mnt/s3/cache',
      ensure => directory,
    }

    exec { 's3fs-install':
      path        => '/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin',
      creates     => '/usr/local/bin/s3fs',
      logoutput   => on_failure,
      command     => '/etc/puppet/modules/s3fs-c/files/bin/install.sh',
      require     => [
                       Package['pkg-config'],
                       Package['build-essential'],
                       Package['fuse-utils'],
                       Package['mime-support'],
                       Package['libfuse-dev'],
                       Package['libcurl4-openssl-dev'],
                       Package['libxml2-dev'],
                       Package['libcrypto++-dev'],
                       File["s3fs-cache-directory"],
                     ],
    }

  }

  define s3fs_mount ($bucket, $owner='root', $uid=0, $group='root', $gid=0, $mode='0700', $access_key, $secret_access_key )
  {
    line { "aws-creds-$bucket":
      file    => '/etc/passwd-s3fs',
      line    => "$bucket:$access_key:$secret_access_key",
      require => [
                   File["aws-creds-file"],
                 ],
    }

#    line { "fstab-$bucket":
#      file    => '/etc/fstab',
#      line    => "s3fs#$bucket  $name     fuse    defaults,noatime,uid=$uid,gid=$gid,allow_other 0 0",
#      #line    => "s3fs#$bucket  $name     fuse    defaults,noatime,uid=$uid,gid=$gid,allow_other,use_cache=/mnt/s3/cache 0 0",
#      require => [
#                   File["aws-creds-file"],
#                 ],
#    }

    file { "$name":
      path    => "$name",
      owner   => "$owner",
      group   => "$group",
      mode    => "$mode",
      ensure  => directory,
      require => [
                   Exec["s3fs-install"],
                 ],
    }

    mount { "s3fs-mount-$bucket":
      name     => $name,
      atboot   => true,
      device   => "s3fs#$bucket",
      ensure   => mounted,
      fstype   => fuse,
      optiones => "defaults,noatime,uid=$uid,gid=$gid,allow_other",
      remounts => true,
      require   => [
                     Line["aws-creds-$bucket"],
                     File["$name"],
                   ],
    }

#    exec { "s3fs-mount-$bucket":
#      path      => '/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin',
#      onlyif    => "/bin/df $name 2>&1 | tail -1 | /bin/grep -E '^s3fs' -qv",
#      logoutput => on_failure,
#      #command   => "s3fs $bucket $name -o default_permissions -o use_cache=/mnt/s3/cache",
#      command   => "mount $name",
#      require   => [
#                     Line["aws-creds-$bucket"],
#                     File["$name"],
#                   ],
#    }

  }

}
