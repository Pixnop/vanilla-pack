#!/usr/bin/env python3
"""Applique les corrections proposees par les agents de relecture.

Chaque agent ecrit un .todo/_pass/<lot>.corr.json contenant des entrees
{dom, cle, avant, apres, motif}. On refuse toute correction dont la valeur
actuelle ne correspond pas au champ "avant" : cela signifierait que l'agent a
travaille sur un etat perime, ou qu'un autre lot est deja passe par la.

On refuse aussi toute correction qui abimerait le balisage ou les marqueurs.
"""
import json
import glob
import os
import re
import sys

BASE = os.path.join(os.path.dirname(__file__), '..', 'translation-fr')
TAGS = ('<font', '</font>', '<a href', '</a>', '<br>', '<strong>', '<i>')


def markers(s):
    return sorted(re.findall(r'\{\d+\}', s))


def main():
    lots = sorted(glob.glob(os.path.join(BASE, '.todo/_pass/*.corr.json')))
    if not lots:
        print('aucun fichier de corrections'); return 1

    applied = refused = 0
    par_lot = []
    for lot in lots:
        nom = os.path.basename(lot).replace('.corr.json', '')
        try:
            corrs = json.load(open(lot, encoding='utf-8'))
        except Exception as e:
            print(f'  {nom:<20} ILLISIBLE: {e}'); continue

        ok = ko = deja = 0
        for c in corrs:
            p = os.path.join(BASE, 'assets', c['dom'], 'lang', 'fr.json')
            if not os.path.exists(p):
                print(f"    refus {c['dom']}/{c['cle']}: fichier absent"); ko += 1; continue
            d = json.load(open(p, encoding='utf-8'))
            k = c['cle']
            if k not in d:
                print(f"    refus {c['dom']}/{k}: cle absente"); ko += 1; continue
            if d[k] == c['apres']:
                deja += 1; continue
            if d[k] != c['avant']:
                print(f"    refus {c['dom']}/{k}: valeur actuelle differente de 'avant'"); ko += 1; continue
            if markers(c['avant']) != markers(c['apres']):
                print(f"    refus {c['dom']}/{k}: marqueurs modifies"); ko += 1; continue
            if any(c['avant'].count(t) != c['apres'].count(t) for t in TAGS):
                print(f"    refus {c['dom']}/{k}: balisage modifie"); ko += 1; continue
            d[k] = c['apres']
            json.dump(d, open(p, 'w', encoding='utf-8'),
                      ensure_ascii=False, indent=2, sort_keys=True)
            ok += 1
        par_lot.append((nom, len(corrs), ok, deja, ko))
        applied += ok
        refused += ko

    print(f"\n{'lot':<20}{'proposees':>10}{'appliquees':>12}{'deja':>7}{'refusees':>10}")
    for n, t, o, dj, k in par_lot:
        print(f'{n:<20}{t:>10}{o:>12}{dj:>7}{k:>10}')
    tot_dj = sum(x[3] for x in par_lot)
    print(f"{'TOTAL':<20}{sum(x[1] for x in par_lot):>10}{applied:>12}{tot_dj:>7}{refused:>10}")
    return 0 if refused == 0 else 2


if __name__ == '__main__':
    sys.exit(main())
