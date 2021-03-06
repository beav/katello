#
# Copyright 2011 Red Hat, Inc.
#
# This software is licensed to you under the GNU General Public
# License as published by the Free Software Foundation; either version
# 2 of the License (GPLv2) or (at your option) any later version.
# There is NO WARRANTY for this software, express or implied,
# including the implied warranties of MERCHANTABILITY,
# NON-INFRINGEMENT, or FITNESS FOR A PARTICULAR PURPOSE. You should
# have received a copy of GPLv2 along with this software; if not, see
# http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt.

require 'openssl'
require 'digest/sha2'

# This module contains functions for hashing and storing passwords with
# SHA512 with 64 characters long random salt. It also includes several other
# password-related utility functions.
module Password

  # Generates a new salt and rehashes the password
  def Password.update(password)
    salt = self.salt
    hash = self.hash(password, salt)
    self.store(hash, salt)
  end

  # Checks the password against the stored password
  def Password.check(password, store)
    hash = self.get_hash(store)
    salt = self.get_salt(store)
    if self.hash(password, salt) == hash
      true
    else
      false
    end
  end

  # Generates random string like for length = 10 => "iCi5MxiTDn"
  def self.generate_random_string(length)
    length.to_i.times.collect { (i = Kernel.rand(62); i += ((i < 10) ? 48 : ((i < 36) ? 55 : 61 ))).chr }.join
  end

  def Password.encrypt(text, passphrase = nil)
    passphrase = File.open('/etc/katello/secure/passphrase', 'rb') { |f| f.read }.chomp if passphrase.nil?
    '$1$' + [ Password.aes_encrypt(text, passphrase) ].pack('m0').gsub("\n", '') # for Ruby 1.8
  rescue Exception => e
    if defined?(Rails) && Rails.logger
      Rails.logger.warn "Unable to encrypt password: #{e}"
    else
      STDERR.puts "Unable to encrypt password: #{e}".chomp
    end
    text # return the input if anything goes wrong
  end

  def Password.decrypt(text, passphrase = nil)
    passphrase = File.open('/etc/katello/secure/passphrase', 'rb') { |f| f.read }.chomp if passphrase.nil?
    return text unless text.start_with? '$1$' # password is plain
    Password.aes_decrypt(text[3..-1].unpack('m0')[0], passphrase)
  rescue Exception => e
    if defined?(Rails) && Rails.logger
      Rails.logger.warn "Unable to decrypt password, returning encrypted version #{e}"
    else
      STDERR.puts "Unable to decrypt password, returning encrypted version #{e}".chomp
    end
    text # return the input if anything goes wrong
  end

  protected

  def Password.aes_encrypt(text, passphrase)
    cipher = OpenSSL::Cipher::Cipher.new("aes-256-cbc")
    cipher.encrypt
    cipher.key = Digest::SHA2.hexdigest(passphrase)
    cipher.iv = Digest::SHA2.hexdigest(passphrase + passphrase)

    encrypted = cipher.update(text)
    encrypted << cipher.final
    encrypted
  end

  def Password.aes_decrypt(text, passphrase)
    cipher = OpenSSL::Cipher::Cipher.new("aes-256-cbc")
    cipher.decrypt
    cipher.key = Digest::SHA2.hexdigest(passphrase)
    cipher.iv = Digest::SHA2.hexdigest(passphrase + passphrase)

    decrypted = cipher.update(text)
    decrypted << cipher.final
    decrypted
  end

  if defined?(Rails) and Rails.env.test?
    PASSWORD_ROUNDS = 1
  else
    PASSWORD_ROUNDS = 500
  end

  # Generates a psuedo-random 64 character string
  def Password.salt
    self.generate_random_string(64)
  end

  # Generates a 128 character hash
  def Password.hash(password, salt)
    digest = "#{password}:#{salt}"
    PASSWORD_ROUNDS.times { digest = Digest::SHA512.hexdigest(digest) }
    digest
  end

  # Mixes the hash and salt together for storage
  def Password.store(hash, salt)
    hash + salt
  end

  # Gets the hash from a stored password
  def Password.get_hash(store)
    store[0..127]
  end

  # Gets the salt from a stored password
  def Password.get_salt(store)
    store[128..191]
  end
end
