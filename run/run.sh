sudo rm /var/log/tarantool/bench.log
sudo rm /var/log/tarantool/bench2.log
sudo rm -rf /var/lib/tarantool/bench/
sudo rm -rf /var/lib/tarantool/bench2/
sudo tarantoolctl restart bench
sudo tarantoolctl restart bench2
#sleep 3
./load.pl --batch_len=5000 --limit=10000
rm load
./post.sh '{"method":"build","id":0,"params":[] }'
rm load
#./post.sh '{"method":"show","id":0,"params":[] }'
#rm load
./post.sh '{"method":"lookup","id":0,"params":["Jonathan"] }'
