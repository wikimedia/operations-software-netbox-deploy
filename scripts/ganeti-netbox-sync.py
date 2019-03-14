#!/usr/bin/env python3
"""
ganeti-netbox-sync

This script synchronizes ganeti Instance state with Netbox virtualization.virtual_hosts state.
"""

import argparse
import json
import logging
import os
import sys

from collections import Counter
from configparser import ConfigParser

import pynetbox.api
import requests
import requests.compat
from requests.auth import HTTPBasicAuth

logger = logging.getLogger()


def parse_command_line_args():
    """Parse command line options."""
    parser = argparse.ArgumentParser()

    parser.add_argument("profile", help="The profile to use from the configuration file.")
    parser.add_argument(
        "-i",
        "--in-json",
        help="the path of a JSON file with the output of the Ganeti RAPI instances endpoint to process instead of accessing the API directly.",
    )
    parser.add_argument(
        "-c", "--config", help="The path to the config file to load.", default="/etc/netbox-ganeti-sync.cfg"
    )
    parser.add_argument(
        "-d", "--dry-run", help="Don't actually commit any changes, just do a dry-run", action="store_true"
    )
    parser.add_argument("-v", "--verbose", help="Output more verbosity.", action="store_true")

    args = parser.parse_args()

    # validation and manipulation
    if args.dry_run:
        args.verbose = True

    return args


def setup_logging(verbose=False):
    """Setup the logging with a custom format to go to stdout."""
    formatter = logging.Formatter(fmt="%(asctime)s [%(levelname)s] %(message)s")
    handler = logging.StreamHandler()
    handler.setFormatter(formatter)
    if not verbose:
        level = logging.INFO
    else:
        level = logging.DEBUG
    handler.setLevel(level)
    logging.getLogger("requests").setLevel(logging.WARNING)  # Silence noisy logger
    logger.addHandler(handler)
    logger.raiseExceptions = False
    logger.setLevel(level)


def dictify_ganeti_host_list(host_list):
    """Converts host list into dictionary keyed by hostname for convenience."""
    return {i["name"].split(".")[0]: i for i in host_list}


def get_ganeti_host_list(api_url, user, password, ca_cert):
    """Gets Instance list from Ganeti API"""
    r = requests.get(
        requests.compat.url_join(api_url, "/2/instances?bulk=1"), auth=HTTPBasicAuth(user, password), verify=ca_cert
    )
    if r.status_code != 200:
        raise Exception("Can't access Ganeti API %s".format(r.status_code))
    return r.json()


def ganeti_host_to_netbox(ganeti_dict, additional_fields):
    """Takes a single entry from the Ganeti host list and returns just the fields pertinent to Netbox
    along with any additional fields that need to be added"""
    shortname = ganeti_dict["name"].split(".")[0]
    output = {
        "name": shortname,
        "vcpus": ganeti_dict["beparams"]["vcpus"],
        "memory": ganeti_dict["beparams"]["memory"],
        "disk": round(sum(ganeti_dict["disk.sizes"]) / 1024, 0),  # ganeti gives megabytes, netbox expects gigabytes
    }
    output.update(additional_fields)
    return output


def sync_ganeti_netbox_host_diff(ganeti_host, netbox_host):
    """Update fields on netbox_host from ganeti_dict, return True if updates are made."""
    updated = False
    if netbox_host.vcpus != ganeti_host["vcpus"]:
        logger.debug("updating vcpus on %s %d -> %d", netbox_host.name, netbox_host.vcpus, ganeti_host["vcpus"])
        netbox_host.vcpus = ganeti_host["vcpus"]
        updated = True
    if netbox_host.memory != ganeti_host["memory"]:
        logger.debug("updating memory on %s %d -> %d", netbox_host.name, netbox_host.memory, ganeti_host["memory"])
        netbox_host.memory = ganeti_host["memory"]
        updated = True
    if netbox_host.disk != ganeti_host["disk"]:
        logger.debug("updating disk on %s %d -> %d", netbox_host.name, netbox_host.disk, ganeti_host["disk"])
        netbox_host.disk = ganeti_host["disk"]
        updated = True

    return updated


def sync_ganeti_to_netbox(netbox_api, netbox_token, cluster_name, ganeti_hosts, dryrun):
    """Preform a sync from the Ganeti host list into the specified Netbox API destination."""
    nbapi = pynetbox.api(netbox_api, token=netbox_token)

    nb_linux_id = nbapi.dcim.platforms.get(slug="linux").id
    nb_cluster_id = nbapi.virtualization.clusters.get(name=cluster_name).id
    nb_server_id = nbapi.dcim.device_roles.get(slug="server").id

    nb_vhosts = {}
    # make a convenient dictionary of netbox hosts
    for host in nbapi.virtualization.virtual_machines.filter(cluster=nb_cluster_id):
        nb_vhosts[host.name] = host

    results = Counter()
    for nb_host_name, nb_host in nb_vhosts.items():
        if nb_host_name not in ganeti_hosts:
            if not dryrun:
                nb_host.delete()
            logger.debug("removed %s from netbox", nb_host_name)
            results["del"] += 1
        else:
            try:
                ganeti_host = ganeti_host_to_netbox(ganeti_hosts[nb_host_name], {})
            except (KeyError, TypeError) as e:
                logger.error(
                    "Host %s raised an exception when trying to convert to Netbox for syncing: %s", nb_host_name, e
                )
                continue

            try:
                diff_result = sync_ganeti_netbox_host_diff(ganeti_host, nb_host)
            except KeyError as e:
                logger.error("Host %s raised an exception when trying to resolve diff: %s", nb_host_name, e)
                continue
            if diff_result:
                logger.debug("updating %s in netbox", nb_host_name)
                if not dryrun:
                    nb_host.save()
                results["update"] += 1

    logger.info("removed %s instances from netbox", results["del"])
    logger.info("updated %s instances from netbox", results["update"])

    for ganeti_host_name, ganeti_host in ganeti_hosts.items():
        if ganeti_host_name in nb_vhosts:
            continue

        try:
            ganeti_host_dict = ganeti_host_to_netbox(
                ganeti_host, {"cluster": nb_cluster_id, "platform": nb_linux_id, "role": nb_server_id}
            )
        except (KeyError, TypeError) as e:
            logger.error(
                "Host %s raised an exception when trying to convert to Netbox for adding: %s", ganeti_host_name, e
            )
            continue
        if dryrun:
            save_result = True
        else:
            try:
                save_result = nbapi.virtualization.virtual_machines.create(ganeti_host_dict)
            except pynetbox.RequestError as e:
                logger.error("Host %s raised an exception when trying to create in Netbox: %s", ganeti_host_name, e)
                continue

        if save_result:
            results["add"] += 1
            logger.debug("adding %s to netbox", ganeti_host_dict["name"])
        else:
            logger.error("error added %s to netbox", ganeti_host_dict["name"])
    logger.info("added %s instances to netbox", results["add"])

    return 0


def main():
    args = parse_command_line_args()
    # Load configuration
    cfg = ConfigParser()
    cfg.read(args.config)
    logger.info("loaded %s configuration", args.config)
    netbox_token = cfg["auth"]["netbox_token"]
    ganeti_user = cfg["auth"]["ganeti_user"]
    ganeti_password = cfg["auth"]["ganeti_password"]
    netbox_api = cfg["netbox"]["api"]
    netbox_cluster = cfg["profile:" + args.profile]["cluster"]
    ganeti_api = cfg["profile:" + args.profile]["api"]
    ganeti_ca_cert = cfg["auth"]["ca_cert"]

    setup_logging(args.verbose)

    logger.debug("using ganeti api at %s", ganeti_api)
    logger.debug("using netbox api at %s", netbox_api)

    if args.dry_run:
        logger.info("*** DRY RUN ***")

    # Load Ganeti host list from API or File
    if args.in_json:
        logger.info("note: loading json file rather than accessing ganeti api %s", args.in_json)
        with open(args.in_json, "r") as in_json:
            ganeti_hosts_json = json.load(in_json)
    else:
        ganeti_hosts_json = get_ganeti_host_list(ganeti_api, ganeti_user, ganeti_password, ganeti_ca_cert)
    ganeti_hosts = dictify_ganeti_host_list(ganeti_hosts_json)
    logger.debug("loaded %s instances from ganeti api", len(ganeti_hosts))

    # Perform synchronization to specified Netbox API / cluster
    return sync_ganeti_to_netbox(netbox_api, netbox_token, netbox_cluster, ganeti_hosts, args.dry_run)


if __name__ == "__main__":
    sys.exit(main())
