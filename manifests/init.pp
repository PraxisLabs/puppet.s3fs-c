# iteego/puppet.s3fs: puppet recipes for use with the s3fs sofware
#                     in debian-based systems.
#
# Copyright 2012 Marcus Pemer and Iteego, Inc.
# Author: Marcus Pemer <marcus@iteego.com>
#
# This file is part of iteego/puppet.s3fs-c.
#
# iteego/puppet.s3fs-c is free software: you can redistribute it and/or modify
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

  define aws_bucket_keys( $file, $bucket, $key, $secret, $ensure = 'present' ) {
    case $ensure {
      default: {
        err ( "unknown ensure value ${ensure}" )
      }
      present: {
        exec { "either-write-${bucket}-${key}-${secret}":
          command => "/bin/echo '${bucket}:${key}:${secret}' >> '${file}'",
          unless  => "/bin/grep -q '^${bucket}:' '${file}'",
        }
        exec { "or-update-${bucket}-${key}-${secret}":
          command => "/bin/sed --in-place 's/${bucket}:.*:.*/${bucket}:${key}:${secret}/' '${file}'",
          unless  => "/bin/grep -q '^${bucket}:${key}:${secret}' '${file}'",
          require => Exec["either-write-${bucket}-${key}-${secret}"],
        }
      }
      absent: {
        exec { "/bin/grep -v '^${bucket}:${key}:${secret}' '${file}' | /usr/bin/tee '${file}' > /dev/null 2>&1":
          onlyif => "/bin/grep -q '^${bucket}:${key}:${secret}' '${file}'",
        }
      }
    }
  }

  define s3fs_installation
  {
    package {
      [
				'pkg-config',
				'fuse-utils',
				'libfuse-dev',
				'libxml2-dev',
				'mime-support',
				'build-essential',
				'libcrypto++-dev',
				'libcurl4-openssl-dev',
			]:
			ensure => present,
#			require => Exec['aptgetupdate'],
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
      #command     => '/etc/puppet/modules/s3fs-c/files/bin/install.sh',
      command     => '/etc/aegirvps/modules/s3fs-c/files/bin/install.sh',
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

  define s3fs_mount ($bucket, $owner='root', $group='root', $mode='0700', $access_key, $secret_access_key )
  {

    #TODO: This recipe has the potential to create multiple lines
    #      for the same bucket! A better approach would be to use
    #      an exec with the "sed -ie 's/pattern/pattern'" instead
    aws_bucket_keys { "aws-creds-$bucket":
      file    => '/etc/passwd-s3fs',
      bucket  => "$bucket",
      key     => "$access_key",
      secret  => "$secret_access_key",
      require => [
                   File["aws-creds-file"],
                 ],
    }

    file { "$name":
      ensure  => directory,
      path    => "$name",
      owner   => "$owner",
      group   => "$group",
      mode    => "$mode",
      require => [
                   Exec["s3fs-install"],
                 ],
    }

    # Calculate our uid and gid
    $uid = uid($owner)
    $gid = gid($group)

    mount { "s3fs-mount-$bucket":
      name     => $name,
      atboot   => true,
      device   => "s3fs#$bucket",
      ensure   => mounted,
      fstype   => fuse,
      options  => "defaults,noatime,uid=$uid,gid=$gid,allow_other",
      remounts => false,
      require  => [
                    Aws_Bucket_Keys["aws-creds-$bucket"],
                    File["$name"],
                  ],
    }

  }

}
