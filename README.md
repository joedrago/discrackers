Discrackers
===========

This project extends the functionality of the online comic book reader [Crackers](https://github.com/joedrago/node-crackers) by adding:

* Authentication (via Discord)
* Per-user progress tracking / storage

Prerequisites
-------------

* A [Discord](https://discord.com/) account. Go make one.

* A new Discord "Application" associated to your account (I have two; one for debugging and one for my actual site). Visit the [Discord Developer Portal](https://discord.com/developers/), go to Applications on the left, and hit `New Application`. Give it a name that matches what the site's name is, as it is the name that Discord will ask users to authenticate with when attempting to access comics. Then go to the `OAuth2` tab on the left and add a Redirect URL. If you're just trying this out locally, it will look something like:

        http://localhost:3003/oauth

  If you're configuring this for its final resting place (perhaps with a real domain name and https), set this accordingly. It should be the location of where you're serving this app with `/oauth` appended to the end. Hit the big green `Save Changes` in the bottom right corner of the web page.

* If you're planning to expose this to the internet (instead of just running it locally), I recommend using [nginx](https://www.nginx.com/) as your HTTPS server, which can easily proxy requests to Discrackers.

Installation
------------

* Clone this repository onto the machine that will host your comics, install its necessary deps via npm, and then globally install Crackers:

        git clone https://github.com/joedrago/discrackers.git
        cd discrackers
        npm install
        npm install -g crackers

  (You may need to use `sudo` for the crackers install.)

* Create `secrets.json` in the `discrackers` directory, which should look similar to this:

        {
            "url": "http://localhost:3003",
            "discordClientID": "YOUR_DISCORD_APP_CLIENT_ID",
            "discordClientSecret": "YOUR_DISCORD_APP_CLIENT_SECRET"
        }

    The `url` here should be the same as what you set in your Redirect URL during the prereqs phase, except with `/oauth` removed, and the other two values are found in the `OAuth2` section of the [Discord Developer Portal](https://discord.com/developers/) for your application.

* Add at least one comic (`.cbz` or `.cbr`) into the `discrackers/root` dir, preferably organized into neat subdirectories. Look at the README.md inside the root dir for some tricks using `crackers merge` to make this easy for yourself, or simply do your own layout. While testing out Discrackers, it might be smart to simply drop in one basic `.cbr`/`.cbz` into `root` and try it out before committing to a full unpack.

* Run Crackers on the `root` dir:

        crackers gen path/to/discrackers/root

  This should unpack and sanitize all found `.cbz` and `.cbr` files, generate cover art, and create a few important files in `root`.

* Edit `root/root.crackers`, and change the lines from:

        {
          "title": "Crackers",
          "progress": "",
          "auth": ""
        }

  to:

        {
          "title": "Your Comic Server Title",
          "progress": "/progress",
          "auth": "/auth"
        }

  The title can be any text you want, but set `progress` to `/progress` and `auth` to `/auth`.

* Run Crackers on the `root` dir _again_:

        crackers gen path/to/discrackers/root

  This will pick up your changes in `root.crackers` and generate a new `index.html` containing your new title and enabling all progress and auth features.

* If you want to proxy Discrackers through `nginx`, add a `server` section to your nginx configuration that looks like this:

        server {
            server_name your.comics.domain.here;

            root /this/path/isnt/actually/used;
            index index.html;

            location / {
                proxy_pass http://127.0.0.1:3003;
                proxy_http_version 1.1;
                proxy_set_header Upgrade $http_upgrade;
                proxy_set_header Connection "upgrade";
                proxy_set_header Host $host;
            }
        }

  If your (sub)domain provided here needs an HTTPS certificate, I highly recommend using Let's Encrypt (and `certbot`) to do the heavy lifting here. It'll add the appropriate additional settings to this `server` block for you and get things ready to go.

* Run Discrackers:

        node bin/discrackers server

* Visit Discrackers in a browser. If you're running it locally for testing/debugging/learning, it will likely be here:

  [http://localhost:3003/](http://localhost:3003/)

  It should explain to you that you need Discord authentication to see the comics, and offer a link. If you click the link, Discord should ask for authorization and then redirect you back to the comics. If you successfully see your comic covers at this point, it works! If not, this guide is probably missing an important step, and you should let me know.

* (Optional) Discrackers currently stores all data in JSON, which can be backed up to a private git repository using the following command:

        node bin/discrackers backup

  This command assumes that the `discrackers` directory has a subdirectory named `backup` which contains a valid git repository which can be `push`ed without a password (typically an SSH key is prepared). Running this command will simply copy all JSON files from `discrackers` into `backup`, attempt to commit them to the repo, and then `git push`. To run this automatically every 6 hours (say), simply run `crontab -e` and add a line like this:

        0 */6 * * * /path/to/your/node /path/to/your/discrackers/bin/discrackers backup

  I recommend running the full command manually once from another directory and seeing the changes appear in the remote repo before having cron do it for you.

Adding / Rearranging Comics
---------------------------

Drop them in root in some organized fashion and simply run crackers on the `root` dir again:

        crackers gen path/to/discrackers/root

You shouldn't even have to restart the server itself.

That's it! Good luck!
