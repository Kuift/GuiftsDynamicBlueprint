// Locate a small set of KAG engine strings, follow their native references,
// and export focused pseudocode for the containing functions and callers.
// @category KAG Research

import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Data;
import ghidra.program.model.listing.DataIterator;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionManager;
import ghidra.program.model.listing.Listing;
import ghidra.program.model.symbol.Reference;
import ghidra.program.model.symbol.ReferenceIterator;
import ghidra.program.model.symbol.ReferenceManager;

import java.io.File;
import java.io.PrintWriter;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

public class ExportKagEngineTargets extends GhidraScript {
    private static final String[] TARGET_STRINGS = {
        "Gathering all files from Base",
        "Waiting for scripts...",
        "Waiting for files...",
        "Server uses mod",
        "server_SendGameResources",
        "server_SendGameResources_Scripts",
        "client_RecdResources_Scripts",
        "server_RecdResourcesOK_Scripts",
        "SENDING %i FILES",
        "SCRIPTS PACKETS SIZE %ib",
        "RunLocalhost",
        "ConnectLocalhost",
        "RestartRules",
        "rebuild()",
        "getGameTime",
        "getTick"
    };

    // Preferred-image addresses reconstructed from ASLR-adjusted GDB stacks.
    // The first group is the server-only SleepEx sample; the second group is
    // the bot-clock sample captured while the main thread was rendering.
    private static final String[][] TARGET_ADDRESSES = {
        { "140055440", "scheduler: updates simulation/frame accumulators" },
        { "1400560b8", "server-only stack: direct SleepEx caller" },
        { "1400d0abf", "server-only stack: scheduler caller" },
        { "140012b5d", "server-only stack: outer loop" },
        { "1408f735c", "server-only stack: runtime wrapper" },
        { "1400012ee", "server-only stack: process entry wrapper" },
        { "140001406", "server-only stack: process entry wrapper" },
        { "14047888c", "bot-clock stack: glDrawElements caller" },
        { "14045a71b", "bot-clock stack: render caller" },
        { "1402425d7", "bot-clock stack: render caller" },
        { "14075bed3", "bot-clock stack: frame caller" },
        { "14013ab51", "bot-clock stack: frame caller" },
        { "1401312e4", "bot-clock stack: frame caller" },
        { "140055b36", "bot-clock stack: main-loop caller" },
        { "1401e69e0", "scheduler callback 1: tick target" },
        { "1401f3300", "scheduler callback 1: slot 0x20 target" },
        { "1403161e0", "scheduler callback 2: tick target" },
        { "140308460", "scheduler callback 2: slot 0x20 target" },
        { "1401f3ef0", "scheduler callback 3: tick target" },
        { "140021870", "scheduler callback 3: slot 0x20 target" },
        { "14012ad70", "scheduler callback 4 (frame-only): tick slot" },
        { "140128790", "scheduler callback 4 (frame-only): slot 0x20 target" }
    };

    private final Map<Address, Set<String>> reasonsByFunction = new LinkedHashMap<>();
    private final Map<Address, Set<String>> relationsByFunction = new LinkedHashMap<>();

    @Override
    protected void run() throws Exception {
        String[] args = getScriptArgs();
        if (args.length < 1) {
            throw new IllegalArgumentException(
                "Expected an output directory and optional preferred-image addresses");
        }
        boolean addressOnly = args.length > 1;

        File outputDirectory = new File(args[0]);
        if (!outputDirectory.isDirectory() && !outputDirectory.mkdirs()) {
            throw new IllegalStateException("Cannot create output directory: " + outputDirectory);
        }

        Listing listing = currentProgram.getListing();
        FunctionManager functions = currentProgram.getFunctionManager();
        ReferenceManager references = currentProgram.getReferenceManager();

        Map<String, List<Address>> stringAddresses = new LinkedHashMap<>();
        if (addressOnly) {
            collectCommandLineAddresses(functions, args);
        }
        else {
            stringAddresses = findTargetStrings(listing);
            collectSeedFunctions(stringAddresses, listing, functions, references);
            collectExplicitAddresses(functions);
            collectImmediateCallers(functions, references);
        }

        List<Function> selectedFunctions = new ArrayList<>();
        for (Address address : relationsByFunction.keySet()) {
            Function function = functions.getFunctionAt(address);
            if (function != null) {
                selectedFunctions.add(function);
            }
        }
        selectedFunctions.sort(Comparator.comparing(Function::getEntryPoint));

        File output = new File(outputDirectory,
            addressOnly ? "kag_address_targets.txt" : "kag_engine_targets.txt");
        try (PrintWriter writer = new PrintWriter(output, StandardCharsets.UTF_8)) {
            writeHeader(writer, stringAddresses, selectedFunctions.size());

            DecompInterface decompiler = new DecompInterface();
            decompiler.toggleCCode(true);
            decompiler.toggleSyntaxTree(true);
            decompiler.setSimplificationStyle("decompile");
            if (!decompiler.openProgram(currentProgram)) {
                throw new IllegalStateException("Decompiler could not open current program");
            }

            try {
                for (Function function : selectedFunctions) {
                    if (monitor.isCancelled()) {
                        break;
                    }
                    exportFunction(writer, decompiler, function);
                }
            }
            finally {
                decompiler.dispose();
            }
        }

        println("KAG focused decompilation exported to " + output.getAbsolutePath());
    }

    private Map<String, List<Address>> findTargetStrings(Listing listing) {
        Map<String, List<Address>> matches = new LinkedHashMap<>();
        for (String target : TARGET_STRINGS) {
            matches.put(target, new ArrayList<>());
        }

        DataIterator dataIterator = listing.getDefinedData(true);
        while (dataIterator.hasNext() && !monitor.isCancelled()) {
            Data data = dataIterator.next();
            Object value = data.getValue();
            if (!(value instanceof String)) {
                continue;
            }

            String text = (String) value;
            for (String target : TARGET_STRINGS) {
                if (text.contains(target)) {
                    matches.get(target).add(data.getAddress());
                }
            }
        }
        return matches;
    }

    private void collectSeedFunctions(Map<String, List<Address>> stringAddresses,
            Listing listing, FunctionManager functions, ReferenceManager references) {
        for (Map.Entry<String, List<Address>> entry : stringAddresses.entrySet()) {
            String target = entry.getKey();
            for (Address stringAddress : entry.getValue()) {
                ReferenceIterator iterator = references.getReferencesTo(stringAddress);
                while (iterator.hasNext()) {
                    Reference reference = iterator.next();
                    Function function = functions.getFunctionContaining(reference.getFromAddress());
                    if (function != null) {
                        addSeed(function, target + " @ " + stringAddress);
                        continue;
                    }

                    // Some compilers introduce a pointer in read-only data. Follow one
                    // additional reference layer so those users are not missed.
                    Data pointer = listing.getDefinedDataAt(reference.getFromAddress());
                    if (pointer == null) {
                        continue;
                    }
                    ReferenceIterator pointerUsers = references.getReferencesTo(pointer.getAddress());
                    while (pointerUsers.hasNext()) {
                        Reference pointerUser = pointerUsers.next();
                        function = functions.getFunctionContaining(pointerUser.getFromAddress());
                        if (function != null) {
                            addSeed(function, target + " via " + pointer.getAddress() +
                                " @ " + stringAddress);
                        }
                    }
                }
            }
        }
    }

    private void addSeed(Function function, String reason) {
        Address entry = function.getEntryPoint();
        reasonsByFunction.computeIfAbsent(entry, ignored -> new LinkedHashSet<>()).add(reason);
        relationsByFunction.computeIfAbsent(entry, ignored -> new LinkedHashSet<>()).add("seed");
    }

    private void collectExplicitAddresses(FunctionManager functions) throws Exception {
        for (String[] target : TARGET_ADDRESSES) {
            collectExplicitAddress(functions, target[0], target[1]);
        }
    }

    private void collectCommandLineAddresses(FunctionManager functions, String[] args)
            throws Exception {
        for (int i = 1; i < args.length; ++i) {
            collectExplicitAddress(functions, args[i], "command-line target");
        }
    }

    private void collectExplicitAddress(FunctionManager functions, String addressText,
            String reason) throws Exception {
        Address address = currentProgram.getAddressFactory()
            .getDefaultAddressSpace().getAddress(addressText);
        Function function = functions.getFunctionContaining(address);
        if (function == null) {
            // Indirect virtual targets have no direct call reference, so the
            // initial analyzer can leave valid entry points undefined.
            disassemble(address);
            function = functions.getFunctionContaining(address);
            if (function == null) {
                function = createFunction(address, null);
            }
        }
        if (function != null) {
            addSeed(function, reason + " @ " + address);
        }
        else {
            println("No containing function recovered for " + reason + " @ " + address);
        }
    }

    private void collectImmediateCallers(FunctionManager functions, ReferenceManager references) {
        List<Address> seeds = new ArrayList<>(reasonsByFunction.keySet());
        for (Address seedAddress : seeds) {
            Function seed = functions.getFunctionAt(seedAddress);
            if (seed == null) {
                continue;
            }

            ReferenceIterator iterator = references.getReferencesTo(seedAddress);
            while (iterator.hasNext()) {
                Reference reference = iterator.next();
                Function caller = functions.getFunctionContaining(reference.getFromAddress());
                if (caller == null || caller.getEntryPoint().equals(seedAddress)) {
                    continue;
                }
                relationsByFunction.computeIfAbsent(caller.getEntryPoint(),
                    ignored -> new LinkedHashSet<>()).add(
                        "calls " + seed.getName() + " @ " + seedAddress +
                        " from " + reference.getFromAddress());
            }
        }
    }

    private void writeHeader(PrintWriter writer, Map<String, List<Address>> stringAddresses,
            int functionCount) {
        writer.println("KAG focused engine decompilation");
        writer.println("generated_utc=" + Instant.now());
        writer.println("program=" + currentProgram.getName());
        writer.println("image_base=" + currentProgram.getImageBase());
        writer.println("selected_functions=" + functionCount);
        writer.println();
        writer.println("STRING MATCHES");
        for (Map.Entry<String, List<Address>> entry : stringAddresses.entrySet()) {
            writer.println(entry.getKey() + " => " + entry.getValue());
        }
        writer.println();
    }

    private void exportFunction(PrintWriter writer, DecompInterface decompiler,
            Function function) {
        Address entry = function.getEntryPoint();
        writer.println("================================================================================");
        writer.println("FUNCTION " + function.getName() + " @ " + entry);
        writer.println("signature=" + function.getSignature());

        Set<String> reasons = reasonsByFunction.getOrDefault(entry, Collections.emptySet());
        for (String reason : reasons) {
            writer.println("string_reason=" + reason);
        }
        for (String relation : relationsByFunction.getOrDefault(entry, Collections.emptySet())) {
            writer.println("relation=" + relation);
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
