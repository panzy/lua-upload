package com.panzy;

import javax.net.SocketFactory;
import java.io.*;
import java.net.Socket;

public class Main {

    public static void main(String[] args) {
        try {
            final String host = args[0];
            final int port = Integer.parseInt(args[1]);

            final Socket socket = SocketFactory.getDefault().createSocket(host, port);

            // send HTTP POST request in a thread
            new Thread(new Runnable()
            {
                @Override
                public void run()
                {
                    try {
                        OutputStream os = socket.getOutputStream();

                        final int contentLen = 5 * 10000;

                        writeText(os, "POST /upload HTTP/1.1\r\n");
                        writeText(os, "Host: " + host + "\r\n");
                        writeText(os, "Content-Type: application/octet-stream\r\n");
                        writeText(os, "Content-Length: " + contentLen + "\r\n");
                        writeText(os, "ext: txt\r\n");
                        writeText(os, "\r\n");

                        for (int i = 0; i < contentLen / 5; ++i) {
                            writeText(os, String.format("%04X ", i));
                        }
                    } catch (IOException e) {
                        e.printStackTrace();
                    }
                }
            }).start();

            // read HTTP response immediately
            BufferedReader br = new BufferedReader(new InputStreamReader(socket.getInputStream()));
            String line;
            do {
                line = br.readLine();
                if (line != null) {
                    System.out.println("< " + line);
                }
            } while (line != null);

        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    private static void writeText(OutputStream os, String text) throws IOException
    {
        os.write(text.getBytes());
        System.out.println("> " + text);
    }

}
