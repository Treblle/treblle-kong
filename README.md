# Treblle Kong Plugin

This plugin captures API request data and sends it to the Treblle API, enabling you to visualize and analyze your API traffic within Treblle. For each API request, the plugin asynchronously transmits relevant details to the Treblle API.

To protect sensitive information, data masking can be enabled, ensuring that confidential data is not sent to Treblle.

In case of a failure when sending data, the plugin automatically retries once, with a default retry interval of 5 seconds. Both the retry count and interval can be customized through the plugin’s configuration.

## How to install

### 1. Install the Treblle plugin

You'll need to clone the [Treblle-kong](https://github.com/Treblle/Treblle-kong) and copy the source code content to `/usr/local/share/lua/5.1/kong/plugins/treblle` location. Sample [Dockerfile](Dockerfile) is available for reference.

### 2. Update your loaded plugins list
In your `kong.conf`, append `treblle` to the `plugins` field (or `custom_plugins` if old version of Kong). Make sure the field is not commented out.

```yaml
plugins = bundled,treblle        # Comma-separated list of plugins this node
                                 # should load. By default, only plugins
                                 # bundled in official distributions are
                                 # loaded via the `bundled` keyword.
```


If you don't have a `kong.conf`, create one from the default using the following command: 
`cp /etc/kong/kong.conf.default /etc/kong/kong.conf`

### 3. Start Kong

Start the Kong server.

### 4. Enable the Treblle plugin Globally

- Create an API in Treblle
- Get the SDK token and API ID from the Treblle dashboard.

```bash
curl -i -X POST --url http://localhost:8001/plugins/ --data "name=treblle" --data "config.api_key=<SDK Token>" --data "config.project_id=<API_ID>";
```

## How to use

How to configure Kong Treblle plugin:

### Terminology
- `plugin`: a plugin executing actions inside Kong before or after a request has been proxied to the upstream API.
- `Service`: the Kong entity representing an external upstream API or microservice.
- `Route`: the Kong entity representing a way to map downstream requests to upstream services.
- `Consumer`: the Kong entity representing a developer or machine using the API. When using Kong, a Consumer only communicates with Kong which proxies every call to the said upstream API.
- `Credential`: a unique string associated with a Consumer, also referred to as an API key.
upstream service: this refers to your own API/service sitting behind Kong, to which client requests are forwarded.
- `API`: a legacy entity used to represent your upstream services. Deprecated in favor of Services since CE 0.13.0 and EE 0.32.

### Enabling the plugin Globally

A plugin which is not associated to any Service, Route or Consumer (or API, if you are using an older version of Kong) is considered "global",
and will be run on every request. Read the [Plugin Reference](https://docs.konghq.com/gateway-oss/2.4.x/admin-api/#add-plugin) and the
[Plugin Precedence](https://docs.konghq.com/gateway-oss/2.4.x/admin-api/#precedence) sections for more information.

```
curl -i -X POST --url http://localhost:8001/plugins/ --data "name=treblle" --data "config.api_key=<SDK Token>" --data "config.project_id=<API_ID>";
```

- `config.api_key`: Your Treblle SDK token can be found in the [Treblle Portal_](https://www.treblle.com/).
After signing up for a Treblle account, create an API in Treblle.  

- `config.project_id`: Your Treblle API ID can be found in the [Treblle Portal_](https://www.treblle.com/).
After signing up for a Treblle account, create an API in Treblle. 

### Enabling the plugin on a Service

Configure this plugin on a [Service](https://docs.konghq.com/gateway-oss/2.4.x/admin-api/#service-object) by making the following request on your Kong server:

```
curl -X POST http://kong:8001/services/{service}/plugins \
    --data "name=treblle"  \
    --data "config.api_key=<SDK Token>" \
    --data "config.project_id=<API_ID>" 
```

- `config.api_key`: Your Treblle SDK token can be found in the [Treblle Portal_](https://www.treblle.com/).
After signing up for a Treblle account, create an API in Treblle.  

- `config.project_id`: Your Treblle API ID can be found in the [Treblle Portal_](https://www.treblle.com/).
After signing up for a Treblle account, create an API in Treblle. 

- `service`: the id or name of the Service that this plugin configuration will target.

### Enabling the plugin on a Route

Configure this plugin on a [Route](https://docs.konghq.com/gateway-oss/2.4.x/admin-api/#route-object) with:


```
curl -X POST http://kong:8001/routes/{route_id}/plugins \
    --data "name=treblle"  \
    --data "config.api_key=<SDK Token>" \
    --data "config.project_id=<API_ID>" 
```

- `config.api_key`: Your Treblle SDK token can be found in the [Treblle Portal_](https://www.treblle.com/).
After signing up for a Treblle account, create an API in Treblle.  

- `config.project_id`: Your Treblle API ID can be found in the [Treblle Portal_](https://www.treblle.com/).
After signing up for a Treblle account, create an API in Treblle. 

- `route_id`: the id of the Route that this plugin configuration will target.


## Parameters

The following tuning options are available for the Treblle Kong plugin.

|Parameter|Default(Kong gateway 1.x, 2.x)|Default(Kong gateway 3.x onwards) |Description|
|---|---|---|---|
|name|||The name of the plugin to use, in this case `treblle`|
|service_id|||The id of the Service which this plugin will target.|
|route_id	|||The id of the Route which this plugin will target.|
|enabled|true|true|Whether this plugin will be applied.|
|config.api_key	|||The Treblle SDK token provided to you by Treblle.|
|config.project_id	|||The Treblle API ID provided to you by Treblle.|
|config.timeout (deprecated)|1000|1000|Timeout in milliseconds when connecting/sending data to Treblle.|
|config.connect_timeout|1000|1000|Timeout in milliseconds when connecting to Treblle.|
|config.send_timeout|5000|5000|Timeout in milliseconds when sending data to Treblle.|
|config.keepalive|5000|5000|Value in milliseconds that defines for how long an idle connection will live before being closed.|
|config.max_callback_time_spent|750|750|Limiter on how much time to send events to Treblle per worker cycle.|
|config.request_max_body_size_limit|100000|100000|Maximum request body size in bytes to log.|
|config.response_max_body_size_limit|100000|100000|Maximum response body size in bytes to log.|
|config.event_queue_size|100000|100000|Maximum number of events to hold in queue before sending to Treblle. In case of network issues when not able to connect/send event to Treblle, skips adding new to event to queue to prevent memory overflow.|
|config.debug|false|false|If set to true, prints internal log messages for debugging integration issues.|
|conf.enable_compression|false|false|If set to true, requests are compressed before sending to Treblle.|
|conf.max_retry_count|1|1|Retry count to send the payload to the Treblle API.|
|conf.retry_interval|5|5|Retry interval between retries. Value is in seconds.|
|conf.mask_keywords|||Masking keywords to be used for the entire payload.|

Sample Curl command to enable masking 

```
curl -i -X POST http://localhost:8001/plugins/ \
--data "name=treblle" \
--data "config.api_key=<sdk_key>" \
--data "config.project_id=<api_id>" \
--data "config.mask_keywords[]=Authorization" \
--data "config.mask_keywords[]=API_Key" \
--data "config.mask_keywords[]=Secure-Id"
```

## Troubleshooting

### How to print debug logs

If you want to print Treblle debug logs, you can set `--data “config.debug=true"` when you enable the plugin.

If you already have Treblle installed, you must update the configuration of the existing instance and not install Treblle twice.
Otherwise, you will have multiple instances of a plugin installed, which Kong does not support.

To update existing plugin with debug option:

## Sample Commands

- Create a Service in Kong

    ```
    curl -X POST http://localhost:8001/services --data name=httpbin-service --data url=https://httpbin.org
    ```

- Create a route for the service

    ```
    curl --location 'http://localhost:8001/services/httpbin-service/routes' \
    --header 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode 'name=httpbin-route' \
    --data-urlencode 'paths%5B%5D=/httpbin' \
    --data-urlencode 'methods%5B%5D=POST'
    ```

- Enable Plugin with Masking

    ```
    curl -i -X POST http://localhost:8001/services/httpbin-service/plugins \
    --data "name=treblle" \
    --data "config.api_key=change" \
    --data "config.project_id=cgh" \
    --data "config.mask_keywords[]=Authorization" \
    --data "config.mask_keywords[]=API_Key" 
    ```
