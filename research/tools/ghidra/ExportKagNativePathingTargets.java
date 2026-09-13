// Dereference the installed-build AngelScript binding thunks for the focused
// pathing/movement surface and export those native targets plus direct callees.
// Raw output belongs on E: (or another ignored private analysis location).
// @category KAG Research

import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionManager;

import java.io.File;
import java.io.PrintWriter;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

public class ExportKagNativePathingTargets extends GhidraScript {
    private static final String[][] BINDING_POINTERS = {
        { "140a02b20", "CBlob.setKeyPressed(keys,bool)" },
        { "140a02a30", "CBlob.isKeyPressed(keys)" },
        { "140a02860", "CBlob.getPosition()" },
        { "140a02bb0", "CBlob.getOldPosition()" },
        { "140a02880", "CBlob.getVelocity()" },
        { "140a027a0", "CBlob.isOnGround()" },
        { "140a032b0", "CBlob.isOnWall()" },
        { "140a027b0", "CBlob.isOnLadder()" },
        { "140a02000", "CMap.rayCastSolid(Vec2f,Vec2f)" },
        { "140a01f40", "CMap.isTileSolid(Vec2f)" },
        { "140a024d0", "CMap.getTile(Vec2f)" },
        { "1409fba00", "CMap.getBlobsInBox(Vec2f,Vec2f,array)" },
        { "140a03f40", "CBrain.EndPath()" }
    };

    private final Map<Address, Set<String>> reasons = new LinkedHashMap<>();

    @Override
    protected void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length != 1) {
            throw new IllegalArgumentException("Expected one output directory argument");
        }

        File outputDirectory = new File(args[0]);
        if (!outputDirectory.isDirectory() && !outputDirectory.mkdirs()) {
            throw new IllegalStateException("Cannot create output directory: " + outputDirectory);
        }

        FunctionManager functions = currentProgram.getFunctionManager();
        Map<String, String> resolvedPointers = new LinkedHashMap<>();

        for (String[] binding : BINDING_POINTERS) {
            Address pointerAddress = address(binding[0]);
            long rawTarget = currentProgram.getMemory().getLong(pointerAddress);
            Address targetAddress = currentProgram.getAddressFactory().getDefaultAddressSpace()
                .getAddress(rawTarget);
            resolvedPointers.put(binding[0] + " " + binding[1], targetAddress.toString());
            Function target = functions.getFunctionContaining(targetAddress);
            if (target == null) {
                disassemble(targetAddress);
                target = functions.getFunctionContaining(targetAddress);
                if (target == null) {
                    target = createFunction(targetAddress, null);
                }
            }
            if (target != null) {
                reasons.computeIfAbsent(target.getEntryPoint(), ignored -> new LinkedHashSet<>())
                    .add(binding[1] + " via pointer " + pointerAddress + " -> " + targetAddress);
            }
        }

        // Include direct call targets from each binding thunk. This is the
        // useful implementation neighborhood without recursively dumping the
        // engine or unrelated callers.
        List<Address> bindingTargets = new ArrayList<>(reasons.keySet());
        for (Address bindingTarget : bindingTargets) {
            Function function = functions.getFunctionAt(bindingTarget);
            if (function == null) {
                continue;
            }
            for (Function callee : function.getCalledFunctions(monitor)) {
                if (callee == null || callee.isExternal()) {
                    continue;
                }
                reasons.computeIfAbsent(callee.getEntryPoint(), ignored -> new LinkedHashSet<>())
                    .add("direct callee of " + function.getName() + " @ " + bindingTarget);
            }
        }

        List<Function> selected = new ArrayList<>();
        for (Address entry : reasons.keySet()) {
            Function function = functions.getFunctionAt(entry);
            if (function != null) {
                selected.add(function);
            }
        }
        selected.sort(Comparator.comparing(Function::getEntryPoint));

        File output = new File(outputDirectory, "kag_native_pathing_targets.txt");
        try (PrintWriter writer = new PrintWriter(output, StandardCharsets.UTF_8)) {
            writer.println("KAG focused native pathing/movement targets");
            writer.println("generated_utc=" + Instant.now());
            writer.println("program=" + currentProgram.getName());
            writer.println("image_base=" + currentProgram.getImageBase());
            writer.println("selected_functions=" + selected.size());
            writer.println();
            writer.println("RESOLVED BINDING POINTERS");
            for (Map.Entry<String, String> pointer : resolvedPointers.entrySet()) {
                writer.println(pointer.getKey() + " => " + pointer.getValue());
            }
            writer.println();

            DecompInterface decompiler = new DecompInterface();
            decompiler.toggleCCode(true);
            decompiler.toggleSyntaxTree(true);
            decompiler.setSimplificationStyle("decompile");
            if (!decompiler.openProgram(currentProgram)) {
                throw new IllegalStateException("Decompiler could not open current program");
            }
            try {
                for (Function function : selected) {
                    if (monitor.isCancelled()) {
                        break;
                    }
                    writer.println("================================================================================");
                    writer.println("FUNCTION " + function.getName() + " @ " + function.getEntryPoint());
                    writer.println("signature=" + function.getSignature());
                    for (String reason : reasons.get(function.getEntryPoint())) {
                        writer.println("reason=" + reason);
                    }
                    writer.println("--------------------------------------------------------------------------------");
                    DecompileResults result = decompiler.decompileFunction(function, 120, monitor);
                    if (!result.decompileCompleted() || result.getDecompiledFunction() == null) {
                        writer.println("DECOMPILE FAILED: " + result.getErrorMessage());
                    }
                    else {
                        writer.println(result.getDecompiledFunction().getC());
                    }
                    writer.println();
                    writer.flush();
                }
            }
            finally {
                decompiler.dispose();
            }
        }

        println("KAG native pathing targets exported to " + output.getAbsolutePath());
    }

    private Address address(String text) throws Exception {
        return currentProgram.getAddressFactory().getDefaultAddressSpace().getAddress(text);
    }
}
