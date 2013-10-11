require 'autotest-email/version'
require 'rmail'
require 'net/imap'
require 'net/smtp'

module Autotest

  module Email

    class << self

      attr_accessor :address, :port, :user_name, :password, :enable_ssl
      attr_accessor :from, :to, :subject, :body, :file_name, :file_path, :reply_to

      def configure
        yield self
      end
    end

    def find_email_by_subject(option={})
      res = nil
      time = 0

      while res == nil and time < 15 do
        time += 1

        imap = connect
        imap.uid_search(['SUBJECT', option[:subject]]).last(20).each do |message_uid|
          envelope = imap.uid_fetch(message_uid, 'ENVELOPE')[0].attr['ENVELOPE']
          res = if "#{envelope.to[0].mailbox}@#{envelope.to[0].host}" == option[:to]
            message_uid
          else
            nil
          end
        end
        imap.disconnect if res.nil?
        sleep 15
      end

      msg = imap.uid_fetch(res, '(UID RFC822.SIZE ENVELOPE BODY[TEXT])')[0]
      body = msg.attr['BODY[TEXT]']

      delete_email(res)

      disconnect(imap)

      return body
    end

    def clear_email_by_subject(subject)
      imap = connect
      imap.uid_search(['SUBJECT', subject]).each do |message_uid|
        delete_email(message_uid)
      end
      disconnect(imap)
    end

    def send_exception_email(options={})
      file_path = options[:file_path].nil? ? Email.file_path : options[:file_path]

      SendMail::send_mail(
        :to => options[:to].nil? ? Email.to : options[:to],
        :subject => options[:subject].nil? ? Email.subject : options[:subject],
        :reply_to => options[:reply_to].nil? ? Email.reply_to : options[:replay_to],
        :body => options[:body].nil? ? Email.body : options[:body],
        :options => {
          :priority => 2,
          :attachments_transfer_encoding => :quoted_printable
        },
        :attachments => [
          {
            :filename => options[:file_name].nil? ? Email.file_name : options[:file_name],
            :mime_type => 'image/png',
            :content => File.open(file_path) {|file| file.sysread(File.size(file))},
            :transfer_encoding => :base64
          }
        ]
      )
    end

    private

    def delete_email(message_uid)
      imap.uid_store(message_uid, "+FLAGS", [:Deleted])
      imap.uid_copy(message_uid, "[Gmail]/Trash")
    end

    def connect
      Net::IMAP.new(Email.address, Email.port, Email.enable_ssl).tap do |imap|
        imap.login(Email.user_name, Email.password)
        imap.select('[Gmail]/All Mail')
      end
    end

    def disconnect(imap)
      imap.expunge
      imap.disconnect
    end

  end

  autoload :SendMail,  'autotest-email/send_mail'

end

Autotest::Email.configure do |config|
  #for get email
  config.address    = 'pop.gmail.com'
  config.port       = 995
  config.user_name  = 'example@gmail.com'
  config.password   = 'password'
  config.enable_ssl = true

  #for send email
  config.from       = 'example@gmail.com'
  config.to         = 'example@gmail.com'
  config.reply_to   = 'noreplay@example.com'
  config.subject    = nil
  config.body       = nil
  config.file_name  = nil
  config.file_path  = nil
end
