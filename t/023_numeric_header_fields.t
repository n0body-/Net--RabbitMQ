use Test::More tests => 12;
use strict;
use warnings;

use Data::Dumper;
use Sys::Hostname;
my $unique = hostname . "-$^O-$^V"; #hostname-os-perlversion
my $exchange = "nr_test_x-numeric_header_fields-$unique";
my $routekey = "nr_test_q-numeric_header_fields-$unique";

#my $dtag1=(unpack("L",pack("N",1)) != 1)?'0100000000000000':'0000000000000001';
#my $dtag2=(unpack("L",pack("N",1)) != 1)?'0200000000000000':'0000000000000002';
my $dtag1 = 1;
my $host = $ENV{'MQHOST'} || "dev.rabbitmq.com";

use_ok('Net::AMQP::RabbitMQ');

my $mq = Net::AMQP::RabbitMQ->new();
ok($mq);

eval { $mq->connect($host, { user => "guest", password => "guest" }); };
is($@, '', "connect");
eval { $mq->channel_open(1); };
is($@, '', "channel_open");
eval { $mq->exchange_declare(1, $exchange, { exchange_type => "fanout", passive => 0, durable => 1, auto_delete => 1 }); };
is($@, '', "exchange_declare");
my $queuename = '';
eval { $queuename = $mq->queue_declare(1, 'nr_test_q-numeric_header_fields', { passive => 0, durable => 1, exclusive => 0, auto_delete => 1 }); };
is($@, '', "queue_declare");
isnt($queuename, '', "queue_declare -> private name");
eval { $mq->queue_bind(1, $queuename, $exchange, $routekey); };
is($@, '', "queue_bind");

my $payload = "Message payload";
my $headers = {
	unsigned_integer => 12345,
	signed_integer   => -12345,
	double           => 3.141,
	string           => "string here",
};

eval { $mq->publish(1, $routekey, $payload, { exchange => $exchange }, { headers => $headers }); };
is($@, '', "publish");
die "Fatal publish failure!" if $@;

eval { $mq->consume(1, $queuename, {consumer_tag=>'ctag', no_local=>0,no_ack=>1,exclusive=>0}); };
is($@, '', "consume");

my $rv = {};
eval { $rv = $mq->recv(); };
is($@, '', "recv");
#$rv->{delivery_tag} =~ s/(.)/sprintf("%02x", ord($1))/esg;
is_deeply($rv,
          {
          'body' => $payload,
          'routing_key' => $routekey,
          'delivery_tag' => $dtag1,
          'redelivered' => 0,
          'exchange' => $exchange,
          'consumer_tag' => 'ctag',
          'props' => { 'headers' => $headers },
          }, "payload");

1;
