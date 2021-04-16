def addr_to_if(addr, facts):
    for interface in facts['ansible_interfaces']:
        ifkey = 'ansible_{}'.format(interface.replace('-','_'))
        if 'ipv4' not in facts[ifkey]:
            continue

        if facts[ifkey]['ipv4']['address'] == addr:
            return interface

    return None


class FilterModule(object):
    def filters(self):
        return {'addr_to_if': addr_to_if}
