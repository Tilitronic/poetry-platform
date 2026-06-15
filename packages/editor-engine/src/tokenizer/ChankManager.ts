// import { ChangeSet } from '@codemirror/state';

// const CHUNK_SIZE = 30
// const CHUNK_MAX = 45   // split threshold
// const CHUNK_MIN = 15   // merge threshold

// type Command =
//   | { type: 'UPDATE_CHUNK'; chunkId: string; tokens: IToken[] }
//   | { type: 'INSERT_CHUNK_AFTER'; afterId: string; chunkId: string; tokens: IToken[] }
//   | { type: 'DELETE_CHUNK'; chunkId: string }

// export class ChunkManager {

//   // Main function — invoked on every CM6 ChangeSet
//   applyChange(changeSet: ChangeSet, getDocText: () => string): Command[] {
//     const commands: Command[] = []

//     // 1. Find all chunks intersecting the change
//     const affectedIds = this.findAffected(changeSet)

//     // 2. Оновити from/to для всіх чанків ПІСЛЯ зміни
//     //    CM6 ChangeSet has the mapPos method — use it
//     this.remapPositions(changeSet, affectedIds)

//     // 3. Ретокенізувати зачеплені чанки
//     for (const chunkId of affectedIds) {
//       const chunk = chunksMap.get(chunkId)!.value
//       const newText = getDocText().slice(chunk.fromPos, chunk.toPos)
//       const newTokens = tokenize(newText, chunk.fromPos)
//       const merged = mergeWithOverrides(newTokens, chunk.tokens)

//     // 4. Check whether to split or merge
//       if (merged.length > CHUNK_MAX) {
//         commands.push(...this.split(chunkId, merged))
//       } else if (merged.length < CHUNK_MIN) {
//         commands.push(...this.mergeWithNeighbor(chunkId, merged))
//       } else {
//         commands.push({ type: 'UPDATE_CHUNK', chunkId, tokens: merged })
//       }
//     }

//     return commands
//   }

//   // Розщеплення одного великого чанку на два
//   private split(chunkId: string, tokens: IToken[]): Command[] {
//     const mid = Math.floor(tokens.length / 2)
//     const leftId = chunkId           // reuse the old ID
//     const rightId = generateId()     // new ID for the right half

//     return [
//       {
//         type: 'UPDATE_CHUNK',
//         chunkId: leftId,
//         tokens: tokens.slice(0, mid)
//       },
//       {
//         type: 'INSERT_CHUNK_AFTER',
//         afterId: leftId,
//         chunkId: rightId,
//         tokens: tokens.slice(mid)
//       }
//     ]
//   }

//   // Merge a small chunk with its left neighbor
//   private mergeWithNeighbor(chunkId: string, tokens: IToken[]): Command[] {
//     const order = chunkOrder.value
//     const idx = order.indexOf(chunkId)
//     if (idx === 0) return [{ type: 'UPDATE_CHUNK', chunkId, tokens }]

//     const neighborId = order[idx - 1]
//     const neighborTokens = chunksMap.get(neighborId)!.value.tokens
//     const merged = [...neighborTokens, ...tokens]

//     // If the merged chunk is too large again — split it
//     if (merged.length > CHUNK_MAX) {
//       return this.split(neighborId, merged).concat([
//         { type: 'DELETE_CHUNK', chunkId }
//       ])
//     }

//     return [
//       { type: 'UPDATE_CHUNK', chunkId: neighborId, tokens: merged },
//       { type: 'DELETE_CHUNK', chunkId }
//     ]
//   }

//   // CM6 mapPos — shifts positions after insert/delete
//   private remapPositions(changeSet: ChangeSet, excludeIds: string[]): void {
//     for (const [id, chunkAtom] of chunksMap) {
//       if (excludeIds.includes(id)) continue  // these are re-tokenized separately
//       const chunk = chunkAtom.value
//       chunkAtom.set({
//         ...chunk,
//         fromPos: changeSet.mapPos(chunk.fromPos),
//         toPos: changeSet.mapPos(chunk.toPos)
//       })
//     }
//   }
// }
