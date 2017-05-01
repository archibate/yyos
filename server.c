#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <unistd.h>
#include <netinet/in.h>
#include <arpa/inet.h>

void process_it(int sock)
{
	close(sock);
}

int svr_main(int argc, char *argv[])
{
	int svr_sock = socket(AF_INET, SOCK_STREAM, 0);
	if (svr_sock < 0) {
		perror("socket");
		goto out;
	}

	int svr_port = atoi(argv[1]);
	const char *svr_ipadr = argv[2];

	const struct sockaddr_in svr_addr = {
		.sin_family = AF_INET,
		.sin_port = htons(svr_port),
		.sin_addr.s_addr = inet_addr(svr_ipadr),
	};
	if (bind(svr_sock, (const struct sockaddr *) &svr_addr,
				sizeof(svr_addr)) < 0) {
		perror("bind");
		goto out_close;
	}

	if (listen(svr_sock, 1) < 0) {
		perror("listen");
		goto out_close;
	}

	while (1) {
		struct sockaddr_in clt_addr;
		socklen_t clt_addr_len = sizeof(clt_addr);
		int clt_sock = accept(svr_sock,
				(struct sockaddr *) &clt_addr,
				&clt_addr_len);
		if (clt_sock < 0) {
			perror("accept");
			goto out_close;
		}
		printf("accepted client at %s:%d\n",
				inet_ntoa(clt_addr.sin_addr),
				ntohs(clt_addr.sin_port));
		pid_t pid = fork();
		if (!pid) {
			close(svr_sock);
			process_it(clt_sock);
		} else {
			close(clt_sock);
		}
	}

out_close:
	close(svr_sock);
out:	return 0;
}

int clt_main(int argc, char *argv[])
{
	int clt_sock = socket(AF_INET, SOCK_STREAM, 0);
	if (clt_sock < 0) {
		perror("socket");
		goto out;
	}

	int svr_port = atoi(argv[1]);
	const char *svr_ipadr = argv[2];

	struct sockaddr_in svr_addr = {
		.sin_family = AF_INET,
		.sin_port = htons(svr_port),
		.sin_addr.s_addr = inet_addr(svr_ipadr),
	};

	if (connect(clt_sock, (const struct sockaddr *) &svr_addr, sizeof(svr_addr) < 0)) {
		perror("connect");
		exit(1);
	}

	process_it(clt_sock);

out_close:
	close(clt_sock);
out:	return 0;
}

int main(int argc, char *argv[])
{
	if (argc < 3) {
		printf("usage: %s svr|clt <ipadr> <port>\n", argv[0]);
		exit(1);
	}
	if (!strcmp(argv[1], "svr")) {
		return svr_main(argc - 1, argv + 1);
	} else if (!strcmp(argv[1], "clt")) {
		return clt_main(argc - 1, argv + 1);
	}
}
