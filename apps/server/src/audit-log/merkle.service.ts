import { Injectable } from '@nestjs/common';
import { sha256 } from '../common/hash.util';

@Injectable()
export class MerkleService {
    buildTree(hashes: string[]): string[][] {
        if (hashes.length === 0) return [];

        const tree: string[][] = [hashes];

        while (tree[tree.length - 1].length > 1) {
            const level = tree[tree.length - 1];
            const nextLevel: string[] = [];

            for (let i = 0; i < level.length; i += 2) {
                const left = level[i];
                const right = level[i + 1] || left; // duplicate if odd

                nextLevel.push(sha256(left + right));
            }

            tree.push(nextLevel);
        }

        return tree;
    }

    getRoot(tree: string[][]): string {
        return tree[tree.length - 1][0];
    }

    getProof(hashes: string[], index: number): { proof: string[]; root: string } {
        let proof: string[] = [];
        let currentIndex = index;
        let level = hashes;

        while (level.length > 1) {
            const nextLevel: string[] = [];

            for (let i = 0; i < level.length; i += 2) {
                const left = level[i];
                const right = level[i + 1] || left;

                // If this pair contains our node → store sibling
                if (i === currentIndex || i + 1 === currentIndex) {
                    const sibling = i === currentIndex ? right : left;
                    proof.push(sibling);
                    currentIndex = Math.floor(i / 2);
                }

                nextLevel.push(sha256(left + right));
            }

            level = nextLevel;
        }

        return {
            proof,
            root: level[0],
        };
    }

    verifyProof(
        leafHash: string,
        proof: string[],
        root: string,
    ): boolean {
        let computed = leafHash;

        for (const sibling of proof) {
            computed = sha256(computed + sibling);
        }

        return computed === root;
    }
}